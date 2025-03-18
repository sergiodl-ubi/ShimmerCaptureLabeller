import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:mutex/mutex.dart';
import 'tools/logging.dart';
import 'src/shimmer3_definitions.dart';
import 'package:vector_math/vector_math.dart';

/// True if sensitivity matrix is diagonal and alignment matrix follows:
/// [  0, -1,  0 ]
/// [ s1,  0,  0 ]  "s" represents a positive or negative sign
/// [  0,  0, -1 ]
///
/// This is true for Shimmer3 GSR+ default calibration values
const optimizedCalibration = true;

DebugPrintCallback debugPrint = customDebugPrint("Shimmer3", true);
Mutex _commMutex = Mutex();

class Shimmer3DataPacket {
  final Set<Sensors> enabledSensors;
  final Uint8List data;
  late DateTime dateTime;
  static const int packetType = 0x00;
  static const int packetTypeLength = 1;
  static const int timestampLength = 3;

  Shimmer3DataPacket(this.enabledSensors, this.data) {
    dateTime = parseDataTimestamp(data[1], data[2], data[3]);
  }

  static DateTime parseDataTimestamp(int byte0, int byte1, int byte2) {
    var ts = byte0 + (byte1 * 256) + (byte2 * 65536);
    return DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  }

  static Shimmer3DataPacket parse(Set<Sensors> enabledSensors, Uint8List data) {
    if (enabledSensors.isEmpty) {
      throw ArgumentError("Enable at least one sensor");
    }
    var validLength = packetTypeLength + timestampLength;
    for (var sensor in enabledSensors) {
      validLength += sensor.packetLength;
    }
    if (data.length != validLength) {
      throw ArgumentError(
          "Provided data packet length (${data.length}) does not match with enabled sensors: $enabledSensors");
    }
    if (data[0] != packetType) {
      throw ArgumentError(
          "Data packet's packet type (${data[0]}) does not match DataPacket($packetType)");
    }
    var timestamp = data[1] + (data[2] * 256) + (data[2] * 65536);
    return Shimmer3DataPacket(enabledSensors, data);
  }

  static Shimmer3DataPacket? tryParse(
      Set<Sensors> enabledSensors, Uint8List data) {
    try {
      return parse(enabledSensors, data);
    } catch (_) {
      return null;
    }
  }

  @override
  int get hashCode => Object.hash(enabledSensors, data);
  @override
  bool operator ==(covariant Shimmer3DataPacket other) {
    if (identical(this, other)) return true;
    return setEquals(enabledSensors, other.enabledSensors) &&
        listEquals(data, other.data);
  }
}

/// A collection of [Signal]'s data of one of Shimmer3's [Sensors].
///
/// If provided, this implementation will store the `Uint8List` stream of bytes
/// in [dataPacket] of a specified [sensorType] and it will automatically parse
/// each of its defined [Signal]'s into their raw integer values.
///
/// If calibration data is provided, each signal can be processed into their
/// real measured values through the [calibratedData] method. The calibrated values
/// will be found in the [data] attribute;
class SensorData {
  final Sensors sensorType;
  late Uint8List dataPacket;
  Map<String, int> rawData = {};
  Map<String, num> data = {};

  SensorData(this.sensorType,
      {Uint8List? dataPacket,
      Vector3? offset,
      Matrix3? sensitivity,
      Matrix3? alignment}) {
    var dataLoaded = false;
    var dataSize = sensorType.getPacketSize();
    if (dataPacket == null) {
      this.dataPacket = Uint8List(dataSize);
      for (var signal in sensorType.signals) {
        rawData[signal.name] = 0;
        data[signal.name] = 0;
      }
    } else if (dataPacket.length == dataSize) {
      this.dataPacket = dataPacket;
      rawData = parsedDataPacket(dataPacket);
      dataLoaded = true;
    } else {
      throw Exception(
          "$sensorType packet length (${dataPacket.length} is not the same as"
          " Sensor type ($sensorType) length (${sensorType.getPacketSize()})");
    }

    if (dataLoaded) {
      if (imuSensors.contains(sensorType)) {
        if (offset != null && sensitivity != null && alignment != null) {
          data = calibratedData(rawData,
              offset: offset, sensitivity: sensitivity, alignment: alignment);
        } else if (offset != null || sensitivity != null || alignment != null) {
          throw Exception(
              "$sensorType loaded with incomplete calibration parameters: "
              "offset ($offset), sensitivity ($sensitivity), alignment ($alignment)");
        }
      } else {
        data = calibratedData(rawData);
      }
    }
  }
  @override
  String toString() {
    var dataStrings = <String>[];
    for (var signal in data.entries) {
      dataStrings.add("${signal.key}: ${signal.value}");
    }
    return "$sensorType: ${dataStrings.join(', ')}";
  }

  Map<String, int> parsedDataPacket(Uint8List dataPacket) {
    Map<String, int> parsedData = {};
    var idx = 0;
    var blob = ByteData.sublistView(dataPacket);
    for (var signal in sensorType.signals) {
      var endianness = signal.type.endianness;
      switch (signal.type.intType) {
        case "Uint8":
          parsedData[signal.name] = blob.getUint8(idx);
          break;
        case "int8":
          parsedData[signal.name] = blob.getInt8(idx);
          break;
        case "Uint16":
          parsedData[signal.name] = blob.getUint16(idx, endianness);
          break;
        case "int16":
          parsedData[signal.name] = blob.getInt16(idx, endianness);
          break;
        case "Uint32":
          parsedData[signal.name] = blob.getUint32(idx, endianness);
          break;
        case "int32":
          parsedData[signal.name] = blob.getInt32(idx, endianness);
          break;
        case "Uint64":
          parsedData[signal.name] = blob.getUint64(idx, endianness);
          break;
        case "int64":
          parsedData[signal.name] = blob.getInt64(idx, endianness);
          break;
      }
      idx += signal.type.byteSize;
    }
    return parsedData;
  }

  /// Calibrates [rawData] against [sensitivity] and [alignment] matrices after being centered by a [offset] vector.
  ///
  /// Calibration follows [alignment]^(-1) • [sensitivity]^(-1) • ([rawData] - [offset])
  /// and returns a properly calibrated [Vector3] vector.
  Vector3 calibratedIMUData(
      Vector3 rawData, Vector3 offset, Matrix3 sensitivity, Matrix3 alignment) {
    var calibratedData = Vector3(0, 0, 0);
    var centeredData = rawData - offset;
    if (optimizedCalibration) {
      // Due the alignment matrix shape at default values, the computation can
      // be simplified to CALn = sign * (1/Sens.m) * (DATA.m - Offset.m)
      // X and Y gets swapped and CALx sign depends on Align[1, 0] sign
      var xSign = alignment.row1.x > 0 ? 1 : -1;
      calibratedData.x = xSign * (1 / sensitivity.row1.y) * centeredData.y;
      calibratedData.y = -1 * (1 / sensitivity.row0.x) * centeredData.x;
      calibratedData.z = -1 * (1 / sensitivity.row2.z) * centeredData.z;
    } else {
      // This is in case the calibration alignment values do not follow:
      // [  0, -1,  0 ]
      // [ s1,  0,  0 ]  "s" representing a positive or negative sign
      // [  0,  0, -1 ]
      // This case is less efficient since requires expensive matrix inversions
      // and vectorized multiplications.
      var result = alignment.clone();
      var invertedSensitivity = sensitivity.clone();
      invertedSensitivity.invert();
      result.invert();
      result.multiply(invertedSensitivity);
      calibratedData.x = result.dotRow(0, centeredData);
      calibratedData.y = result.dotRow(1, centeredData);
      calibratedData.z = result.dotRow(2, centeredData);
    }
    return calibratedData;
  }

  Map<String, num> calibratedData(Map<String, int> rawData,
      {Vector3? offset, Matrix3? sensitivity, Matrix3? alignment}) {
    Map<String, num> calibratedData = {};
    switch (sensorType) {
      case Sensors.dataTimestamp:
        calibratedData["Timestamp"] = rawData["Timestamp"] ?? 0;
        break;
      case Sensors.lowNoiseAccel:
      case Sensors.wideRangeAccel:
      case Sensors.gyroscope:
      case Sensors.magnetometer:
        var rawDataVector = Vector3(
          (rawData["X"] ?? 0).toDouble(),
          (rawData["Y"] ?? 0).toDouble(),
          (rawData["Z"] ?? 0).toDouble(),
        );
        var result =
            calibratedIMUData(rawDataVector, offset!, sensitivity!, alignment!);
        calibratedData["X"] = result.x;
        calibratedData["Y"] = result.y;
        calibratedData["Z"] = result.z;
        break;
      case Sensors.gsr:
        break;
      case Sensors.battery:
        break;
      case Sensors.ppg:
        break;
      case Sensors.pressureTemp:
        break;
    }
    return calibratedData;
  }
}

class Shimmer3Event {
  final DateTime datetime;
  final Uint8List message;

  Shimmer3Event(this.message, {DateTime? datetime}) : datetime = DateTime.now();
  Shimmer3Event.fromMilliseconds(this.message, int timestamp)
      : datetime = DateTime.fromMillisecondsSinceEpoch(timestamp);

  @override
  String toString() => "${datetime.toIso8601String()}: $message";

  @override
  int get hashCode => Object.hash(datetime, message);
  @override
  bool operator ==(covariant Shimmer3Event other) {
    if (identical(this, other)) return true;
    return datetime == other.datetime && message == other.message;
  }
}

class Shimmer3 {
  final BluetoothDevice device;
  late FlutterBlueClassic _blueClassic;
  late StreamController<Shimmer3Event> _controller;
  BluetoothConnection? _connection;
  bool _streaming = false;

  StreamSubscription? _readSubscription;
  List<Shimmer3Event> receivedEvents = [];
  final ackTimeout = 10;

  Shimmer3(this.device) {
    _blueClassic = FlutterBlueClassic(usesFineLocation: false);
    _controller = StreamController<Shimmer3Event>.broadcast();
  }

  bool get isConnected => _connection?.isConnected ?? false;
  bool get isStreaming => _streaming;
  Stream<Shimmer3Event> get stream => _controller.stream;

  Future<bool> connect() async {
    if (isConnected) {
      return true;
    }
    var conn = await _blueClassic.connect(device.address);
    if (conn == null) {
      debugPrint("Failed to connect to $device");
      return false;
    }
    _connection = conn;
    _readSubscription = _connection!.input?.listen((buffer) {
      if (buffer.isEmpty) {
        return;
      }
      var event = Shimmer3Event(buffer);
      debugPrint("Packet received: $event");
      if (MessageCodes.acknowledge.sameAsMessage(buffer)) {
        receivedEvents.add(event);
        return;
      }
      // Stream out the event
      _controller.add(event);
    });
    return true;
  }

  Future<void> disconnect() async {
    _connection?.dispose();
    _readSubscription?.cancel();
  }

  Future<bool> sendData(Uint8List data) async {
    if (!(await connect())) {
      return false;
    }
    try {
      _connection!.output.add(data);
      await _connection!.output.allSent;
    } catch (err) {
      debugPrint("Failed to send data ($data): ${err.toString()}");
      return false;
    }
    return true;
  }

  int flushQueue() {
    var queueLength = receivedEvents.length;
    receivedEvents.clear();
    return queueLength;
  }

  Future<bool> sendCommand(String description, Uint8List payload) async {
    debugPrint("TX $description: $payload");
    if (!(await sendData(payload))) {
      debugPrint("Failed to $description: data not sent");
      return false;
    }
    if (!(await waitForAck(timeout: ackTimeout, reference: description))) {
      debugPrint("Failed to $description: ack timeout");
      return false;
    }
    return true;
  }

  Future<bool> waitForAck({timeout = 10, reference = ""}) async {
    var acknowledged = false;
    var now = DateTime.now().millisecondsSinceEpoch;
    var expirationTime = now + (timeout * 1000);
    while (!acknowledged && !(now > expirationTime)) {
      if (receivedEvents.isEmpty) {
        await Future.delayed(Duration(milliseconds: 50));
        now = DateTime.now().millisecondsSinceEpoch;
        continue;
      }
      for (final (idx, event) in receivedEvents.indexed) {
        if (MessageCodes.acknowledge.sameAsMessage(event.message)) {
          acknowledged = true;
          receivedEvents.removeAt(idx);
          if (reference.isNotEmpty) {
            debugPrint("Ack received for: $reference");
          }
          break;
        }
      }
      await Future.delayed(Duration(milliseconds: 50));
      now = DateTime.now().millisecondsSinceEpoch;
    }
    return acknowledged;
  }

  Future<bool> initialize(List<Sensors> sensors, {sampleRate = 100}) async {
    return _commMutex.protect<bool>(() async {
      int command, byte0, byte1, byte2;
      flushQueue();
      stopStreaming();

      // Set up sensors
      int configuration = 0;
      for (var sensor in sensors) {
        configuration += 1 << sensor.enableBitShift;
      }
      command = MessageCodes.initSensors.value;
      byte0 = (configuration & 0x00ff0000) >> 16;
      byte1 = (configuration & 0x0000ff00) >> 8;
      byte2 = (configuration & 0x000000ff);
      Uint8List payload = Uint8List.fromList([command, byte0, byte1, byte2]);

      if (!(await sendCommand("set up sensors", payload))) {
        return false;
      }

      // Enable expansion board internal power
      command = MessageCodes.enableExpIntPower.value;
      payload = Uint8List.fromList([command, 1]);

      if (!(await sendCommand("enable expansion board power", payload))) {
        return false;
      }

      // Set sampling rate
      command = MessageCodes.setSamplingRate.value;
      int clockWait = ((1 << 15) / sampleRate).toInt();
      byte0 = (clockWait & 0x00ff);
      byte1 = (clockWait & 0xff00) >> 8;
      payload = Uint8List.fromList([command, byte0, byte1]);

      if (!(await sendCommand("set up sampling rate", payload))) {
        return false;
      }

      flushQueue();
      return true;
    });
  }

  Future<bool> startStreaming() async {
    return _commMutex.protect<bool>(() async {
      var payload = MessageCodes.startStreaming.asUint8List();
      if (!(await sendCommand("starting streaming", payload))) {
        return false;
      }
      _streaming = true;
      return true;
    });
  }

  Future<bool> stopStreaming() async {
    return _commMutex.protect<bool>(() async {
      var payload = MessageCodes.stopStreaming.asUint8List();
      if (!(await sendCommand("stopping streaming", payload))) {
        return false;
      }
      _streaming = false;
      return true;
    });
  }
}
