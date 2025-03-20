import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:mutex/mutex.dart';
import '../tools/logging.dart';
import 'shimmer3_definitions.dart';
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
Map<int, MessageCodes> messageCodesDictionary = MessageCodes.asDictionaryMap();

class ResponseFrame {
  final Uint8List packetBytes;
  late MessageCodes responseType;
  final packetHeaderLength = 2;

  ResponseFrame(this.packetBytes) {
    responseType = _verify(packetBytes);
  }

  MessageCodes _verify(Uint8List bytes) {
    if (bytes.length > 2) {
      throw ArgumentError("Missing response data");
    }
    var ackByte = bytes[0];
    var typeByte = bytes[1];
    if (ackByte != 0xFF) {
      throw ArgumentError("Response frame start ($ackByte) is not Ack byte");
    }
    MessageCodes? type = messageCodesDictionary[typeByte];
    if (type == null) {
      throw ArgumentError(
          "Response type ($typeByte) is not part of [MessageCodes] enum");
    }
    return type;
  }

  static ResponseFrame parse(Uint8List data) => ResponseFrame(data);

  static ResponseFrame? tryParse(Uint8List data) {
    try {
      return parse(data);
    } catch (_) {
      return null;
    }
  }

  void parseDataFrame() {}

  @override
  int get hashCode => Object.hash(packetBytes);

  @override
  bool operator ==(covariant DataFrame other) {
    if (identical(this, other)) return true;
    return listEquals(packetBytes, other.packetBytes);
  }
}

class DataFrame {
  /// in the order as they will appear in [packetBytes]
  final List<Sensors> enabledSensors;
  final Uint8List packetBytes;
  static const int packetType = 0x00;
  static const int packetTypeLength = 1;

  // Unix timestamp in milliseconds
  int configurationTimestampMs;

  // Calibration Vectors ordered as [offset, sensitivity, alignment]
  //
  // Does not accepts an IMUCalibrationData object since new vectors are created
  // on each vector getter call. We want to reuse the same calibration objects
  // for every DataFrame object to avoid wasting memory and cpu cycles.
  (Vector3, Matrix3, Matrix3)? imuCalibrationData;
  BMP280CalibrationData? bmp280calibrationData;
  List<SensorData> sensors = [];

  DataFrame(
    this.enabledSensors,
    this.packetBytes, {
    this.configurationTimestampMs = 0,
    this.imuCalibrationData,
    this.bmp280calibrationData,
  }) {
    enabledSensors.insert(0, Sensors.dataTimestamp);
    _verify(enabledSensors, packetBytes);
    if (configurationTimestampMs != 0 ||
        imuCalibrationData != null ||
        bmp280calibrationData != null) {
      parseDataFrame(
          configTimestampMs: configurationTimestampMs,
          imuCalibrationData: imuCalibrationData,
          bmp280CalibrationData: bmp280calibrationData);
    }
  }

  static bool isDataFrame(Uint8List bytes) =>
      bytes.isNotEmpty && bytes[0] == packetType;

  static void _verify(List<Sensors> enabledSensors, Uint8List bytes) {
    if (enabledSensors.length <= 1) {
      throw ArgumentError("Enable at least one sensor");
    }
    var validLength = packetTypeLength;
    for (var sensor in enabledSensors) {
      validLength += sensor.getPacketSize();
    }
    if (bytes.length != validLength) {
      throw ArgumentError(
          "Provided data packet length (${bytes.length}) does not match with enabled sensors: $enabledSensors");
    }
    if (bytes[0] != packetType) {
      throw ArgumentError(
          "Data packet's packet type (${bytes[0]}) does not match dataPacket($packetType)");
    }
  }

  static DataFrame parse(List<Sensors> enabledSensors, Uint8List data) =>
      DataFrame(enabledSensors, data);

  static DataFrame? tryParse(List<Sensors> enabledSensors, Uint8List data) {
    try {
      return parse(enabledSensors, data);
    } catch (_) {
      return null;
    }
  }

  void parseDataFrame({
    int? configTimestampMs,
    (Vector3, Matrix3, Matrix3)? imuCalibrationData,
    BMP280CalibrationData? bmp280CalibrationData,
  }) {
    if (configTimestampMs != null) {
      configurationTimestampMs = configTimestampMs;
    }
    var idx = packetTypeLength;
    int endIdx;
    for (var sensor in enabledSensors) {
      endIdx = idx + sensor.getPacketSize();
      var sensorData = SensorData(
        sensor,
        configurationTimestampMs: configurationTimestampMs,
        rawBytes: packetBytes.sublist(idx, endIdx),
        imuCalibrationData: imuCalibrationData,
        bmp280Coefficients: bmp280CalibrationData,
      );
      sensors.add(sensorData);
      idx = endIdx;
    }
  }

  @override
  int get hashCode => Object.hash(enabledSensors, packetBytes);

  @override
  bool operator ==(covariant DataFrame other) {
    if (identical(this, other)) return true;
    return listEquals(enabledSensors, other.enabledSensors) &&
        listEquals(packetBytes, other.packetBytes);
  }
}

/// A collection of [Signal]'s data of one of Shimmer3's [Sensors].
///
/// If provided, this implementation will store the `Uint8List` stream of bytes
/// in [rawBytes] of a specified [sensorType] and it will automatically parse
/// each of its defined [Signal]'s into their raw integer values.
///
/// If calibration data is provided, each signal can be processed into their
/// real measured values through the [calibratedData] method. The calibrated values
/// will be found in the [data] attribute;
class SensorData {
  final Sensors sensorType;
  late Uint8List rawBytes;
  Map<String, int> rawData = {};
  Map<String, num> data = {};
  int configurationTimestampMs;
  (Vector3, Matrix3, Matrix3)? imuCalibrationData;
  BMP280CalibrationData? bmp280Coefficients;

  SensorData(
    this.sensorType, {
    Uint8List? rawBytes,
    this.configurationTimestampMs = 0,
    this.imuCalibrationData,
    this.bmp280Coefficients,
  }) {
    var dataLoaded = false;
    var dataSize = sensorType.getPacketSize();

    if (rawBytes == null) {
      this.rawBytes = Uint8List(dataSize);
      for (var signal in sensorType.signals) {
        rawData[signal.name] = 0;
        data[signal.name] = 0;
      }
    } else if (rawBytes.length == dataSize) {
      this.rawBytes = rawBytes;
      rawData = parsedDataPacket(rawBytes);
      dataLoaded = true;
    } else {
      throw Exception(
          "$sensorType packet length (${rawBytes.length} is not the same as"
          " Sensor type ($sensorType) length (${sensorType.getPacketSize()})");
    }

    if (dataLoaded) {
      calibrateData();
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

  void calibrateData() {
    if (imuSensors.contains(sensorType)) {
      // If all calibration vectors are given for a IMU Sensor type data
      // the rawData will be automatically processed.
      if (imuCalibrationData != null) {
        data = calibratedData(rawData, imuCalibrationData: imuCalibrationData);
      }
      // If no calibration vectors are given, no calibration is done on rawData
    } else if (sensorType == Sensors.pressureTemp) {
      if (bmp280Coefficients != null) {
        data = calibratedData(rawData, bmp280Coefficients: bmp280Coefficients);
      }
    } else {
      // Any other type of data can be statically processed.
      data = calibratedData(rawData);
    }
  }

  Map<String, int> parsedDataPacket(Uint8List dataPacket) {
    Map<String, int> parsedData = {};
    var idx = 0;
    var blob = ByteData.sublistView(dataPacket);
    for (var signal in sensorType.signals) {
      parsedData[signal.name] = signal.getIntFromDataBlob(blob, idx);
      idx += signal.type.byteSize;
    }
    return parsedData;
  }

  /// Calibrates [rawData] against [sensitivity] and [alignment] matrices after centered by an [offset] vector.
  ///
  /// Calibration follows [alignment]^(-1) • [sensitivity]^(-1) • ([rawData] - [offset])
  /// and returns a properly calibrated [Vector3] vector.
  Vector3 calibratedIMUData(
    Vector3 rawData,
    (Vector3, Matrix3, Matrix3) imuCalibrationData,
  ) {
    var (offset, sensitivity, alignment) = imuCalibrationData;
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

  Map<String, num> calibratedData(
    Map<String, int> rawData, {
    (Vector3, Matrix3, Matrix3)? imuCalibrationData,
    BMP280CalibrationData? bmp280Coefficients,
  }) {
    Map<String, num> calibratedData = {};
    switch (sensorType) {
      case Sensors.dataTimestamp:
        var timestampMs =
            (rawData["Timestamp"] ?? 0) + configurationTimestampMs;
        calibratedData["Timestamp"] = timestampMs / 1000;
        break;
      case Sensors.lowNoiseAccel:
      case Sensors.wideRangeAccel:
      case Sensors.gyroscope:
      case Sensors.magnetometer:
        if (imuCalibrationData == null) {
          throw Exception(
              "$sensorType cannot be calibrated without [imuCalibrationData]");
        }
        var rawDataVector = Vector3(
          (rawData["X"] ?? 0).toDouble(),
          (rawData["Y"] ?? 0).toDouble(),
          (rawData["Z"] ?? 0).toDouble(),
        );
        var calibrated = calibratedIMUData(rawDataVector, imuCalibrationData);
        calibratedData["X"] = calibrated.x;
        calibratedData["Y"] = calibrated.y;
        calibratedData["Z"] = calibrated.z;
        break;
      case Sensors.gsr:
        const range3RawLowerLimit = 683;
        int rawValue = rawData["ADC"] ?? 0;
        var rangeResistorID = (rawValue & 0xC000) >> 14;
        var rangeResistor = gsrRangeResistor[rangeResistorID]!;
        var (minR, maxR) = gsrResistanceRange[rangeResistorID]!;
        int adcValue = rawValue & 0x0FFF;
        if (adcValue <= 0) {
          calibratedData["GSRResistance_kOhms"] = 0;
          calibratedData["GSRConductance_uS"] = 0;
          break;
        }
        if (rangeResistorID == 3 && adcValue < range3RawLowerLimit) {
          adcValue = range3RawLowerLimit;
        }
        var resistance = rangeResistor / (((adcValue * (3 / 4095)) / 0.5) - 1);
        if (resistance > maxR) {
          resistance = maxR;
        } else if (resistance < minR) {
          resistance = minR;
        }
        calibratedData["GSRResistance_kOhms"] = resistance / 1000;
        calibratedData["GSRConductance_uS"] = 1 / resistance;
        break;
      case Sensors.battery:
        const deviceVoltageDropFactor = 1.988;
        int adcValue = rawData["ADC"] ?? 0;
        var voltage = (adcValue * 3 / 4095) * deviceVoltageDropFactor;
        calibratedData["Battery_V"] = voltage;
        break;
      case Sensors.ppg:
        int adcValue = rawData["ADC"] ?? 0;
        var voltage = (adcValue * 3000 / 4095);
        calibratedData["PPG_mV"] = voltage;
        break;
      case Sensors.pressureTemp:
        var rawTemp = rawData["Temp"] ?? 0;
        var rawPress = (rawData["Press"] ?? 0) >> 4;

        var C = bmp280Coefficients!;
        var centeredTemp = rawTemp - C.p1;
        var x1 = centeredTemp * C.p2 >> 10;
        var x2 = ((centeredTemp * centeredTemp) >> 12) * C.p3 >> 14;
        var tempFine = x1 + x2;
        calibratedData["Temp_C"] = ((tempFine * 5 + 128) >> 8) / 100;

        var press = 0;
        var var1 = tempFine - 128000;
        var var2 = var1 * var1 * C.p6;
        var2 = var2 + ((var1 * C.p5) << 17);
        var2 = var2 + (C.p4 << 35);
        var1 = ((var1 * var1 * C.p3) >> 8) + ((var1 * C.p2) << 12);
        var1 = (((1 << 47) + var1)) * C.p1 >> 33;
        if (var1 != 0) {
          press = 1048576 - rawPress;
          press = ((((press << 31) - var2) * 3125) / var1).toInt();
          var1 = (C.p9 * (press >> 13) * (press >> 13)) >> 25;
          var2 = (C.p8 * press) >> 19;
          press = ((press + var1 + var2) >> 8) + (C.p7 << 4);
        }
        calibratedData["Press_Pa"] = press / 256;
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

  // Device Configuration
  int dataBufferSize = 1;

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
      if (MessageCodes.acknowledged.sameAsMessage(buffer)) {
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
        if (MessageCodes.acknowledged.sameAsMessage(event.message)) {
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

  Future<bool> getDeviceConfiguration() async {}

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
      command = MessageCodes.setSensors.value;
      byte0 = (configuration & 0x00ff0000) >> 16;
      byte1 = (configuration & 0x0000ff00) >> 8;
      byte2 = (configuration & 0x000000ff);
      Uint8List payload = Uint8List.fromList([command, byte0, byte1, byte2]);

      if (!(await sendCommand("set up sensors", payload))) {
        return false;
      }

      // Enable expansion board internal power
      command = MessageCodes.setExpansionBoardInternalPower.value;
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

      // TODO: Set Real World Clock

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
