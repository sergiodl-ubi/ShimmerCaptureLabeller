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
Mutex _sendCmdMutex = Mutex();

class ResponseFrame {
  final Uint8List packetBytes;
  late MessageCodes responseType;
  final packetHeaderLength = 1;
  List<Signal> data = [];

  ResponseFrame(this.packetBytes) {
    responseType = _verify(packetBytes);
    debugPrint("To parse ResponseFrame of type ($responseType) with signals ${responseType.responseSignals}");
    parseResponseFrame();
  }

  MessageCodes _verify(Uint8List bytes) {
    if (bytes.length <= 1) {
      throw ArgumentError("Missing response data");
    }
    var typeByte = bytes[0];
    MessageCodes? type = messageCodesDictionary[typeByte];
    if (type == null) {
      throw ArgumentError("Response type ($typeByte) is not part of [MessageCodes] enum");
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

  void parseResponseFrame() {
    var blob = ByteData.sublistView(packetBytes, packetHeaderLength);
    var idx = 0;
    for (var signal in responseType.responseSignals!) {
      var newSignal = Signal.fromByteData(signal, blob, idx: idx);
      debugPrint("Signal processed: $newSignal");
      data.add(newSignal);
      idx += signal.type.byteSize;
    }
  }

  @override
  int get hashCode => Object.hash(responseType, packetBytes);

  @override
  bool operator ==(covariant ResponseFrame other) {
    if (identical(this, other)) return true;
    return listEquals(packetBytes, other.packetBytes);
  }
}

class DataFrame {
  /// in the order as they will appear in [packetBytes]
  late List<Sensors> enabledSensors;
  final Uint8List packetBytes;
  static const int packetType = 0x00;
  static const int packetTypeLength = 1;

  // Calibration Vectors ordered as [offset, sensitivity, alignment]
  //
  // Does not accepts an IMUCalibrationData object since new vectors are created
  // on each vector getter call. We want to reuse the same calibration objects
  // for every DataFrame object to avoid wasting memory and cpu cycles.
  (Vector3, Matrix3, Matrix3)? analogAccelCalibrationData;
  (Vector3, Matrix3, Matrix3)? gyroscopeCalibrationData;
  (Vector3, Matrix3, Matrix3)? magnetometerCalibrationData;
  (Vector3, Matrix3, Matrix3)? wrAccelCalibrationData;
  BMP280CalibrationData? bmp280calibrationData;
  List<SensorData> sensors = [];

  DataFrame(
    List<Sensors> enabledSensors,
    this.packetBytes, {
    this.analogAccelCalibrationData,
    this.gyroscopeCalibrationData,
    this.magnetometerCalibrationData,
    this.wrAccelCalibrationData,
    this.bmp280calibrationData,
  }) {
    this.enabledSensors = List.from(enabledSensors);
    this.enabledSensors.insert(0, Sensors.dataTimestamp);
    _verify(this.enabledSensors, packetBytes);
    if (analogAccelCalibrationData != null ||
        gyroscopeCalibrationData != null ||
        magnetometerCalibrationData != null ||
        wrAccelCalibrationData != null ||
        bmp280calibrationData != null) {
      parseDataFrame(
        analogAccelCalibrationData: analogAccelCalibrationData,
        gyroscopeCalibrationData: gyroscopeCalibrationData,
        magnetometerCalibrationData: magnetometerCalibrationData,
        wrAccelCalibrationData: wrAccelCalibrationData,
        bmp280CalibrationData: bmp280calibrationData,
      );
    }
  }

  static bool isDataFrame(Uint8List bytes) => bytes.isNotEmpty && bytes[0] == packetType;

  static void _verify(List<Sensors> enabledSensors, Uint8List bytes) {
    if (enabledSensors.length <= 1) {
      throw ArgumentError("Enable at least one sensor");
    }
    var validLength = packetTypeLength;
    for (var sensor in enabledSensors) {
      validLength += sensor.getPacketSize();
    }
    if (bytes.length != validLength) {
      var repr = enabledSensors.map((sensor) => "$sensor(${sensor.getPacketSize()})").toList();
      throw ArgumentError(
        "Provided data packet length (${bytes.length}) does not match with enabled sensors: [ACK, ${repr.join(', ')}]",
      );
    }
    if (bytes[0] != packetType) {
      throw ArgumentError("Data packet's packet type (${bytes[0]}) does not match dataPacket($packetType)");
    }
  }

  static DataFrame parse(List<Sensors> enabledSensors, Uint8List data) => DataFrame(enabledSensors, data);

  static DataFrame? tryParse(List<Sensors> enabledSensors, Uint8List data) {
    try {
      return parse(enabledSensors, data);
    } catch (_) {
      return null;
    }
  }

  void parseDataFrame({
    (Vector3, Matrix3, Matrix3)? analogAccelCalibrationData,
    (Vector3, Matrix3, Matrix3)? gyroscopeCalibrationData,
    (Vector3, Matrix3, Matrix3)? magnetometerCalibrationData,
    (Vector3, Matrix3, Matrix3)? wrAccelCalibrationData,
    BMP280CalibrationData? bmp280CalibrationData,
  }) {
    var idx = packetTypeLength;
    int endIdx;
    for (var sensor in enabledSensors) {
      endIdx = idx + sensor.getPacketSize();
      (Vector3, Matrix3, Matrix3)? imuCalibrationData;
      switch (sensor) {
        case Sensors.lowNoiseAccel:
          imuCalibrationData = analogAccelCalibrationData;
          break;
        case Sensors.gyroscope:
          imuCalibrationData = gyroscopeCalibrationData;
          break;
        case Sensors.magnetometer:
          imuCalibrationData = magnetometerCalibrationData;
          break;
        case Sensors.wideRangeAccel:
          imuCalibrationData = wrAccelCalibrationData;
          break;
        default:
          break;
      }
      var sensorData = SensorData(
        sensor,
        rawBytes: packetBytes.sublist(idx, endIdx),
        imuCalibrationData: imuCalibrationData,
        bmp280Coefficients: bmp280CalibrationData,
      );
      sensors.add(sensorData);
      idx = endIdx;
    }
    debugPrint("DataFrame parsed: $this");
  }

  @override
  int get hashCode => Object.hash(enabledSensors, packetBytes);

  @override
  bool operator ==(covariant DataFrame other) {
    if (identical(this, other)) return true;
    return listEquals(enabledSensors, other.enabledSensors) && listEquals(packetBytes, other.packetBytes);
  }

  @override
  String toString() => "DataFrame \nraw data: $packetBytes\nparsed data: $sensors";
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
  List<Signal> signalData = [];
  (Vector3, Matrix3, Matrix3)? imuCalibrationData;
  BMP280CalibrationData? bmp280Coefficients;
  static int configurationTimestampMs = 0; // Unix Time at configuration time (with SET_RWC)
  static int prevTickTimestamp = 0;
  static int rawTimestampOverflowCounter = 0;

  SensorData(this.sensorType, {Uint8List? rawBytes, this.imuCalibrationData, this.bmp280Coefficients}) {
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
        " Sensor type ($sensorType) length (${sensorType.getPacketSize()})",
      );
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

  ByteData paddedByteList(SignalIntTypes type, Uint8List dataPacket) {
    switch (type) {
      case SignalIntTypes.i24l:
      case SignalIntTypes.u24l:
        var isNegative = ((dataPacket[2] & 0x80) >> 7) == 1;
        var value = (dataPacket[2] << 16) + (dataPacket[1] << 8) + dataPacket[0];
        var buffer = ByteData(4);
        if (type == SignalIntTypes.i24l && isNegative) {
          buffer.setInt32(0, value.toSigned(24), Endian.little);
        } else {
          buffer.setUint32(0, value, Endian.little);
        }
        return buffer;
      case SignalIntTypes.i24b:
      case SignalIntTypes.u24b:
        var isNegative = ((dataPacket[0] & 0x80) >> 7) == 1;
        var value = (dataPacket[0] << 16) + (dataPacket[1] << 8) + dataPacket[2];
        var buffer = ByteData(4);
        if (type == SignalIntTypes.i24b && isNegative) {
          buffer.setInt32(0, value.toSigned(24), Endian.big);
        } else {
          buffer.setUint32(0, value, Endian.big);
        }
        return buffer;
      default:
        return ByteData.sublistView(dataPacket);
    }
  }

  Map<String, int> parsedDataPacket(Uint8List dataPacket) {
    Map<String, int> parsedData = {};
    var idx = 0;
    debugPrint("Parsing $dataPacket of $sensorType");
    for (var signal in sensorType.signals) {
      var blob = paddedByteList(signal.type, Uint8List.sublistView(dataPacket, idx, idx + signal.type.byteSize));
      String attributeName = "";
      switch (signal) {
        case Signals.dataTimestamp:
          attributeName = "Timestamp";
          break;
        case Signals.lowNoiseAccelX:
        case Signals.wideRangeAccelX:
        case Signals.gyroscopeX:
        case Signals.magnetometerX:
          attributeName = "X";
          break;
        case Signals.lowNoiseAccelY:
        case Signals.wideRangeAccelY:
        case Signals.gyroscopeY:
        case Signals.magnetometerY:
          attributeName = "Y";
          break;
        case Signals.lowNoiseAccelZ:
        case Signals.wideRangeAccelZ:
        case Signals.gyroscopeZ:
        case Signals.magnetometerZ:
          attributeName = "Z";
          break;
        case Signals.gsrADC:
        case Signals.batteryADC:
        case Signals.ppgADC:
          attributeName = "ADC";
          break;
        case Signals.temperature:
          attributeName = "Temp";
          break;
        case Signals.pressure:
          attributeName = "Press";
          break;
        default:
          attributeName = "unknown";
          break;
      }
      debugPrint("Checking idx: $idx for ${signal.name} with length ${signal.type.byteSize}");
      parsedData[attributeName] = Signal.getIntFromByteData(signal.type, blob);
      debugPrint("Parsed signal: ${parsedData[attributeName]}");
      idx += signal.type.byteSize;
    }
    return parsedData;
  }

  /// Calibrates [rawData] against [sensitivity] and [alignment] matrices after centered by an [offset] vector.
  ///
  /// Calibration follows [alignment]^(-1) • [sensitivity]^(-1) • ([rawData] - [offset])
  /// and returns a properly calibrated [Vector3] vector.
  Vector3 calibratedIMUData(Vector3 rawData, (Vector3, Matrix3, Matrix3) imuCalibrationData) {
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

  /// Converts a [rawTimestamp] integer coming from a DataFrame to a timestamp that considers a unsigned 24b that can overflow
  /// [dataMaxRawValue] is the maximum capacity of the data raw value register, and 1 is added to count for the overflow tick
  int tickTimestamp(int rawTimestamp) =>
      rawTimestamp + ((ClockMetadata.shimmer3.dataMaxRawValue + 1) * rawTimestampOverflowCounter);

  Map<String, num> calibratedData(
    Map<String, int> rawData, {
    (Vector3, Matrix3, Matrix3)? imuCalibrationData,
    BMP280CalibrationData? bmp280Coefficients,
    (int configTimestampMs, int prevTickTS, int overflowCounter)? clockMetadata,
  }) {
    Map<String, num> calibratedData = {};
    debugPrint("Calibration, rawValue: $rawData");
    switch (sensorType) {
      case Sensors.dataTimestamp:
        // A shimmer3 device's timestamp is only a clock tick counter, counting from the last time it was configured
        // you need to take into account a unsigned 24 bit (3byte) integer overflow and then add the timestamp of
        // the last time it was configured. In case of power interruption, the clock will reset.
        var tickTS = tickTimestamp(rawData["Timestamp"] ?? 0);
        if (prevTickTimestamp > tickTS) {
          // overflow of timestamp raw value has happened, increase <rawTimestampOverflowCounter> and recalculate
          rawTimestampOverflowCounter += 1;
          tickTS = tickTimestamp(rawData["Timestamp"] ?? 0);
        }
        prevTickTimestamp = tickTS;
        // Divide by internal clock freq to get seconds, and convert it into milliseconds
        var timestampMs = (tickTS / ClockMetadata.shimmer3.clockFreq) * 1000;
        // Add configurationTimestamp offset in milliseconds
        calibratedData["Timestamp"] = timestampMs + configurationTimestampMs;
        break;
      case Sensors.lowNoiseAccel:
      case Sensors.wideRangeAccel:
      case Sensors.gyroscope:
      case Sensors.magnetometer:
        if (imuCalibrationData == null) {
          throw Exception("$sensorType cannot be calibrated without [imuCalibrationData]");
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
        var resistanceRange = gsrResistanceRange[rangeResistorID]!;
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
        if (resistance > resistanceRange.max) {
          resistance = resistanceRange.max;
        } else if (resistance < resistanceRange.min) {
          resistance = resistanceRange.min;
        }
        calibratedData["GSRResistance_kOhms"] = resistance / 1000;
        calibratedData["GSRConductance_uS"] = 1 / resistance;
        break;
      case Sensors.battery:
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

enum Shimmer3EventTypes { commandAck, response, data, unknown }

class Shimmer3Event {
  final Uint8List message;
  late DateTime datetime;
  late Shimmer3EventTypes type;
  MessageCodes? responseType;

  Shimmer3Event(this.message, {DateTime? datetime}) {
    this.datetime = datetime ?? DateTime.now();
    type = parseType(message);
    if (type == Shimmer3EventTypes.response) {
      responseType = messageCodesDictionary[message.elementAt(1)];
    }
  }

  Shimmer3Event.fromMilliseconds(this.message, int timestamp) {
    datetime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    type = parseType(message);
    if (type == Shimmer3EventTypes.response) {
      responseType = messageCodesDictionary[message.elementAt(1)];
    }
  }

  @override
  String toString() => "${datetime.toIso8601String()}: ($type) $message";

  @override
  int get hashCode => Object.hash(datetime, type, message);

  @override
  bool operator ==(covariant Shimmer3Event other) {
    if (identical(this, other)) return true;
    return datetime == other.datetime && message == other.message && type == other.type;
  }

  static Shimmer3EventTypes parseType(Uint8List message) {
    var firstByte = message.first;
    var size = message.length;
    var eventType = Shimmer3EventTypes.unknown;
    do {
      if (size > 4 && MessageCodes.dataPacket.value == firstByte) {
        eventType = Shimmer3EventTypes.data;
        break;
      }
      if (size == 1 && MessageCodes.acknowledged.value == firstByte) {
        eventType = Shimmer3EventTypes.commandAck;
        break;
      }
      if (size == 1) {
        break;
      }
      MessageCodes? responseType = messageCodesDictionary[message.elementAt(1)];
      if (size > 2 && MessageCodes.acknowledged.value == firstByte && responseType != null) {
        eventType = Shimmer3EventTypes.response;
        break;
      }
    } while (false);
    if (eventType == Shimmer3EventTypes.unknown) {
      debugPrint("Shimmer3Event message type could not be identified: $message");
    }
    return eventType;
  }
}

class Shimmer3 {
  final BluetoothDevice device;
  late FlutterBlueClassic _blueClassic;
  late StreamController<DataFrame> _dataStreamer;
  Uint8List? _dataBuffer;
  BluetoothConnection? _connection;
  bool _streaming = false;

  StreamSubscription? _readSubscription;
  List<Shimmer3Event> commandReplies = [];
  Map<MessageCodes, List<Signal>> deviceConfiguration = {};
  final ackTimeout = 10;

  // Device status
  List<Sensors> enabledSensors = [];
  String chargingStatus = "";
  double batteryVoltage = 0;
  bool isStreamingToBluetooth = false;
  bool isLoggingToSD = false;
  bool isSensing = false;
  bool isDocked = false;

  // Device Configuration. Default values from manual and example code.
  // This data should be updated during device initialization with the device's actual values.
  DateTime? realWorldClock;
  int rawTimestampValueOverflowCount = 0;
  double samplingRate = 0; // Hz
  // IMUCalibrationData analogAccelCalibrationData = IMUDefaultCalibrations.lowNoiseAccelKXTC92050.vectors;
  // IMUCalibrationData gyroscopeCalibrationData = IMUDefaultCalibrations.gyroscopeMPU910_250DPS.vectors;
  // IMUCalibrationData magnetometerCalibrationData = IMUDefaultCalibrations.magnetometerLSM303AHTR_49Ga.vectors;
  // IMUCalibrationData wrAccelCalibrationData = IMUDefaultCalibrations.wideRangeAccelLSM303AHTR_2G.vectors;
  (Vector3, Matrix3, Matrix3)? analogAccelCalibrationData;
  (Vector3, Matrix3, Matrix3)? gyroscopeCalibrationData;
  (Vector3, Matrix3, Matrix3)? magnetometerCalibrationData;
  (Vector3, Matrix3, Matrix3)? wrAccelCalibrationData;
  BMP280CalibrationData bmp280calibrationData = BMP280CalibrationData();
  double wrAccelRange = lsm303AHTRAccelRange[0] ?? 2.0;
  double wrAccelDataRate = lsm303AHTRAccelDataRate[4] ?? 100; // Hz
  bool wrAccelLowPower = false;
  bool wrAccelHighRes = false;
  int gyroscopeRange = mpu9X50GyroRange[0] ?? 250; // dps, Degrees per Second
  double gyroscopeDataRate = 51.28;
  double magnetometerGain = lsm303AHTRMagRange[0] ?? 49.152;
  double magnetometerDataRate = lsm303AHTRMagDataRate[3] ?? 100;
  double mpuAccelRange = mpu9X50AccelRange[0] ?? 2.0;
  ({double min, double max}) gsrRange = gsrResistanceRange[4]!;
  String bmpX80PressResolution = "";
  List<Signals> dataSignals = [];
  int dataPacketByteSize = 0;

  /// how many samples will be send on each data report during streaming
  /// only bufferSize = 1 is implemented
  int bufferSize = 0;

  Shimmer3(this.device) {
    _blueClassic = FlutterBlueClassic(usesFineLocation: false);
    _dataStreamer = StreamController<DataFrame>.broadcast();
  }

  bool get isConnected => _connection?.isConnected ?? false;

  bool get isStreaming => _streaming;

  Stream<DataFrame> get stream => _dataStreamer.stream;

  Future<bool> connect() async {
    if (isConnected) {
      return true;
    }
    var connectionError = "";
    try {
      var conn = await _blueClassic.connect(device.address);
      if (conn == null) {
        connectionError = "Failed to connect to $device";
        debugPrint(connectionError);
        return false;
      }
      _connection = conn;
    } catch (error) {
      connectionError = error.toString();
      debugPrint(connectionError);
      return false;
    }
    _readSubscription = _connection!.input?.listen(packetReceivedHandler);
    return true;
  }

  Future<void> disconnect() async {
    _connection?.dispose();
    _readSubscription?.cancel();
  }

  DataFrame buildDataFrame(Uint8List buffer) => DataFrame(
    enabledSensors,
    buffer,
    analogAccelCalibrationData: analogAccelCalibrationData,
    gyroscopeCalibrationData: gyroscopeCalibrationData,
    magnetometerCalibrationData: magnetometerCalibrationData,
    wrAccelCalibrationData: wrAccelCalibrationData,
    bmp280calibrationData: bmp280calibrationData,
  );

  void packetReceivedHandler(Uint8List buffer) {
    if (buffer.isEmpty) {
      return;
    }
    var event = Shimmer3Event(buffer);
    if (event.type == Shimmer3EventTypes.unknown && _dataBuffer != null && _dataBuffer!.length < dataPacketByteSize) {
      // We have an incomplete dataPacket in [_dataBuffer], this packet is most likely the continuation
      event.type = Shimmer3EventTypes.data;
    }
    switch (event.type) {
      case Shimmer3EventTypes.commandAck:
      case Shimmer3EventTypes.response:
        commandReplies.add(event);
        break;
      case Shimmer3EventTypes.data:
        var isDataIncomplete = buffer.length != dataPacketByteSize;
        if (isDataIncomplete && _dataBuffer == null) {
          // Data sample got split, safe first part for later
          debugPrint("Data sample split, expected $dataPacketByteSize bytes, saving ${buffer.length} bytes for later.");
          _dataBuffer = Uint8List.fromList(buffer);
          break;
        } else if (isDataIncomplete && _dataBuffer!.length < dataPacketByteSize) {
          _dataBuffer = Uint8List.fromList(_dataBuffer! + buffer);
          debugPrint("Data buffer added ${buffer.length} bytes. Now is ${_dataBuffer!.length} bytes long.");
          if (_dataBuffer!.length < dataPacketByteSize) {
            debugPrint("Not enough data yet (expected total: $dataPacketByteSize)");
            break;
          } else if (_dataBuffer!.length == dataPacketByteSize) {
            debugPrint("Data buffer completed, creating DataFrame with: $_dataBuffer");
            _dataStreamer.add(buildDataFrame(_dataBuffer!));
            _dataBuffer = null;
            break;
          } else {
            /// you will arrive here if the dataPacket was split and device's dataBuffer was set over "1"
            /// (more than one sample per dataPacket). This has not been implemented yet.
            debugPrint(
              "Data buffer size (${_dataBuffer!.length}) exceeded expected size ($dataPacketByteSize), "
              "skipping this DataFrame.",
            );
            _dataBuffer = null;
            break;
          }
        } else {
          _dataStreamer.add(buildDataFrame(buffer));
        }
        break;
      case Shimmer3EventTypes.unknown:
        break;
    }
    if (event.type == Shimmer3EventTypes.commandAck || event.type == Shimmer3EventTypes.response) {
      commandReplies.add(event);
      return;
    }
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

  int flushCommandReplies() {
    var queueLength = commandReplies.length;
    commandReplies.clear();
    return queueLength;
  }

  Future<(bool, Uint8List?)> sendCommand(
    String description,
    MessageCodes command, {
    List<int>? data,
    MessageCodes? responseType,
  }) async {
    final result = await _sendCmdMutex.protect<(bool, Uint8List?)>(() async {
      bool success = false;
      Uint8List? responseData;
      var payloadList = [command.value];
      if (data != null) {
        payloadList.addAll(data);
      }
      var payload = Uint8List.fromList(payloadList);
      debugPrint("TX $description: $payload");
      // Send command
      if (!(await sendData(payload))) {
        debugPrint("Failed to $description: data not sent");
        return (false, null);
      }
      // wait for acknowledge of command
      (success, responseData) = await waitForAck(
        timeout: ackTimeout,
        reference: description,
        responseType: responseType,
      );
      if (!success) {
        debugPrint("Failed to $description: ack timeout");
      }
      debugPrint("RX: ${responseData ?? 'no extra data'}");
      return (success, responseData);
    });
    return result;
  }

  Future<(bool, Uint8List?)> waitForAck({timeout = 10, reference = "", MessageCodes? responseType}) async {
    var acknowledged = false;
    Uint8List? byteData;
    var now = DateTime.now().millisecondsSinceEpoch;
    var expirationTime = now + (timeout * 1000);
    while (!acknowledged && !(now > expirationTime)) {
      if (commandReplies.isEmpty) {
        await Future.delayed(Duration(milliseconds: 50));
        now = DateTime.now().millisecondsSinceEpoch;
        continue;
      }
      for (final (idx, event) in commandReplies.indexed) {
        if (MessageCodes.acknowledged.sameAsMessage(event.message)) {
          acknowledged = true;
        }
        if (event.type == Shimmer3EventTypes.response && event.responseType! == responseType) {
          byteData = Uint8List.sublistView(event.message, 1);
          acknowledged = true;
        }
        if (acknowledged) {
          commandReplies.removeAt(idx);
          if (reference.isNotEmpty) {
            debugPrint("Ack received for: $reference");
          }
          break;
        }
      }
      await Future.delayed(Duration(milliseconds: 50));
      now = DateTime.now().millisecondsSinceEpoch;
    }
    return (acknowledged, byteData);
  }

  /// Sends a read configuration command and saves the result into [deviceConfiguration] instance variable
  ///
  /// It returns a Record of the following type (bool success, Uint8List? responseData)
  Future<(bool success, List<Signal> responseSignals)> readConfiguration(
    MessageCodes command,
    MessageCodes response,
    String description,
  ) async {
    var (success, responseData) = await sendCommand(description, command, responseType: response);
    if (!success) {
      return (false, <Signal>[]);
    }
    var responseSignals = ResponseFrame(responseData!).data;
    deviceConfiguration[response] = responseSignals;
    return (success, responseSignals);
  }

  Future<bool> getDeviceConfiguration() async {
    bool success = false;
    List<Signal> responseSignals;
    flushCommandReplies();
    // await stopStreaming();

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getFWVersion,
      MessageCodes.fwVersion,
      "get firmware version",
    );
    if (!success) return false;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getDeviceVersion,
      MessageCodes.deviceVersion,
      "get device version",
    );
    if (!success) return false;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getChargeStatusLED,
      MessageCodes.chargeStatusLED,
      "get battery charging status",
    );
    if (!success) return false;
    chargingStatus = responseSignals.first.text!;

    // Weird format for getting information of the expansion board
    Uint8List? responseData;
    (success, responseData) = await sendCommand(
      "get expansion board information",
      MessageCodes.getExpansionBoardID,
      data: [0x03, 0x00],
      responseType: MessageCodes.expansionBoardID,
    );
    if (!success) return false;
    deviceConfiguration[MessageCodes.expansionBoardID] = ResponseFrame(responseData!).data;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getBluetoothVersionString,
      MessageCodes.bluetoothVersionString,
      "get bluetooth chip version information",
    );
    if (!success) return false;

    success = await readDeviceStatus();
    if (!success) return false;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getLSM303DLHCAccelRange,
      MessageCodes.lsm303DLHCAccelRange,
      "get LSM303 accel range",
    );
    if (!success) return false;
    wrAccelRange = responseSignals.first.float!;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getSamplingRate,
      MessageCodes.samplingRateResponse,
      "get device sampling rate",
    );
    if (!success) return false;
    samplingRate = responseSignals.first.float!;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getLSM303DLHCMagGain,
      MessageCodes.lsm303DLHCMagGain,
      "get LSM303 Magnetometer Gain",
    );
    if (!success) return false;
    magnetometerGain = responseSignals.first.float!;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getMPU9X50GyroRange,
      MessageCodes.mpu9X50GyroRange,
      "get MPU9X50 Gyroscope Range",
    );
    if (!success) return false;
    gyroscopeRange = responseSignals.first.integer!;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getLSM303DLHCAccelSamplingRate,
      MessageCodes.lsm303DLHCAccelSamplingRate,
      "get LSM303 Accelerometer Sampling Rate",
    );
    if (!success) return false;
    wrAccelDataRate = responseSignals.first.float!;

    success = await readAllIMUCalibrationCoefficients();
    if (!success) return false;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getExpansionBoardInternalPower,
      MessageCodes.expansionBoardInternalPower,
      "get expansion board internal power state",
    );
    if (!success) return false;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getShimmerNameString,
      MessageCodes.shimmerNameString,
      "get shimmer name",
    );
    if (!success) return false;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getExperimentIDString,
      MessageCodes.experimentIDString,
      "get experiment id",
    );
    if (!success) return false;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getShimmerNumber,
      MessageCodes.shimmerNumber,
      "get shimmer number",
    );
    if (!success) return false;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getConfigTimestampString,
      MessageCodes.configTimestampString,
      "get time of last configuration",
    );
    if (!success) return false;

    success = await readDataSignalConfiguration();
    if (!success) return false;

    (success, responseSignals) = await readConfiguration(
      MessageCodes.getBluetoothBaudRate,
      MessageCodes.bluetoothBaudRate,
      "get serial bluetooth baud rate",
    );
    if (!success) return false;

    success = await readBMP280CalibrationCoefficients();
    if (!success) return false;

    return true;
  }

  /// InStream capable function
  Future<bool> readDeviceStatus() async {
    var (success, responseData) = await sendCommand(
      "get device status",
      MessageCodes.getStatus,
      responseType: MessageCodes.instreamCommand,
    );
    if (!success) {
      return false;
    }
    var u8Status = ResponseFrame(responseData!).data[0].rawValue!;
    var blob = ByteData(1);
    blob.setUint8(0, u8Status);
    List<Signal> data = [];
    for (var signal in MessageCodes.status.responseSignals!) {
      data.add(Signal.fromByteData(signal, blob));
    }
    debugPrint("Device Status processed: $data");
    deviceConfiguration[MessageCodes.status] = data;
    isStreamingToBluetooth = data[0].isSet!;
    isLoggingToSD = data[1].isSet!;
    isSensing = data[2].isSet!;
    isDocked = data[3].isSet!;
    return true;
  }

  /// InStream capable function
  Future<bool> readBatteryState() async {
    var (success, responseData) = await sendCommand(
      "get battery state",
      MessageCodes.getBatteryVoltage,
      responseType: MessageCodes.instreamCommand,
    );
    if (!success) {
      return false;
    }
    var u24bBatteryStateData = ResponseFrame(responseData!).data[0].rawValue!;
    var blob = ByteData(4);
    blob.setUint32(0, u24bBatteryStateData, Endian.big); // 0x00, 0xMSB, 0x2SB, 0xLSB
    List<Signal> data = [];
    var idx = 1; // skip first byte
    for (var signal in MessageCodes.batteryVoltage.responseSignals!) {
      data.add(Signal.fromByteData(signal, blob, idx: idx));
      idx += signal.type.byteSize;
    }
    deviceConfiguration[MessageCodes.batteryVoltage] = data;
    batteryVoltage = data[0].float!;
    chargingStatus = data[1].text!;
    return true;
  }

  Future<bool> readAllIMUCalibrationCoefficients() async {
    var (success, responseData) = await sendCommand(
      "get all IMU calibration coefficients",
      MessageCodes.getAllCalibration,
      responseType: MessageCodes.allCalibration,
    );
    if (!success) {
      return false;
    }
    var signals = ResponseFrame(responseData!).data;
    deviceConfiguration[MessageCodes.allCalibration] = signals;
    int2Double(Signal sig) => sig.integer!.toDouble();
    getDouble(Signal sig) => sig.float!;

    var calData = IMUCalibrationData(
      [int2Double(signals[0]), int2Double(signals[1]), int2Double(signals[2])],
      [int2Double(signals[3]), 0, 0, 0, int2Double(signals[4]), 0, 0, 0, int2Double(signals[5])],
      [
        int2Double(signals[6]),
        int2Double(signals[7]),
        int2Double(signals[8]),
        int2Double(signals[9]),
        int2Double(signals[10]),
        int2Double(signals[11]),
        int2Double(signals[12]),
        int2Double(signals[13]),
        int2Double(signals[14]),
      ],
    );
    analogAccelCalibrationData = (calData.offset, calData.sensitivity, calData.alignment);

    calData = IMUCalibrationData(
      [int2Double(signals[15]), int2Double(signals[16]), int2Double(signals[17])],
      [getDouble(signals[18]), 0, 0, 0, getDouble(signals[19]), 0, 0, 0, getDouble(signals[20])],
      [
        int2Double(signals[21]),
        int2Double(signals[22]),
        int2Double(signals[23]),
        int2Double(signals[24]),
        int2Double(signals[25]),
        int2Double(signals[26]),
        int2Double(signals[27]),
        int2Double(signals[28]),
        int2Double(signals[29]),
      ],
    );
    gyroscopeCalibrationData = (calData.offset, calData.sensitivity, calData.alignment);

    calData = IMUCalibrationData(
      [int2Double(signals[30]), int2Double(signals[31]), int2Double(signals[32])],
      [int2Double(signals[33]), 0, 0, 0, int2Double(signals[34]), 0, 0, 0, int2Double(signals[35])],
      [
        int2Double(signals[36]),
        int2Double(signals[37]),
        int2Double(signals[38]),
        int2Double(signals[39]),
        int2Double(signals[40]),
        int2Double(signals[41]),
        int2Double(signals[42]),
        int2Double(signals[43]),
        int2Double(signals[44]),
      ],
    );
    magnetometerCalibrationData = (calData.offset, calData.sensitivity, calData.alignment);

    calData = IMUCalibrationData(
      [int2Double(signals[45]), int2Double(signals[46]), int2Double(signals[47])],
      [int2Double(signals[48]), 0, 0, 0, int2Double(signals[49]), 0, 0, 0, int2Double(signals[50])],
      [
        int2Double(signals[51]),
        int2Double(signals[52]),
        int2Double(signals[53]),
        int2Double(signals[54]),
        int2Double(signals[55]),
        int2Double(signals[56]),
        int2Double(signals[57]),
        int2Double(signals[58]),
        int2Double(signals[59]),
      ],
    );
    wrAccelCalibrationData = (calData.offset, calData.sensitivity, calData.alignment);

    return true;
  }

  Future<bool> readBMP280CalibrationCoefficients() async {
    var (success, responseData) = await sendCommand(
      "get BMP280 calibration coefficients",
      MessageCodes.getBMP280CalibrationCoefficients,
      responseType: MessageCodes.bmp280CalibrationCoefficients,
    );
    if (!success) {
      return false;
    }
    var signals = ResponseFrame(responseData!).data;
    deviceConfiguration[MessageCodes.bmp280CalibrationCoefficients] = signals;
    bmp280calibrationData = BMP280CalibrationData(
      t1: signals[0].integer!,
      t2: signals[0].integer!,
      t3: signals[0].integer!,
      p1: signals[0].integer!,
      p2: signals[0].integer!,
      p3: signals[0].integer!,
      p4: signals[0].integer!,
      p5: signals[0].integer!,
      p6: signals[0].integer!,
      p7: signals[0].integer!,
      p8: signals[0].integer!,
      p9: signals[0].integer!,
    );
    return true;
  }

  Future<bool> readDataSignalConfiguration() async {
    var (success, responseData) = await sendCommand(
      "get data signals configuration",
      MessageCodes.inquiryCommand,
      responseType: MessageCodes.inquiryResponse,
    );
    if (!success) {
      return false;
    }
    var data = ResponseFrame(responseData!).data;
    deviceConfiguration[MessageCodes.inquiryResponse] = data;
    var map = {for (var signal in data) signal.type: signal};

    samplingRate = map[Signals.samplingRateResponse]!.float!;
    wrAccelDataRate = map[Signals.configLSM303AccelSamplingRate]!.float!;
    wrAccelRange = map[Signals.configLSM303AccelRange]!.float!;
    wrAccelLowPower = map[Signals.configLSM303AccelLowPower]!.isSet!;
    wrAccelHighRes = map[Signals.configLSM303AccelHighRes]!.isSet!;
    gyroscopeDataRate = map[Signals.configMPU9X50SamplingRate]!.float!;
    magnetometerGain = map[Signals.configLSM303MagGain]!.float!;
    magnetometerDataRate = map[Signals.configLSM303MagSamplingRate]!.float!;
    gyroscopeRange = map[Signals.configMPU9X50GyroRange]!.integer!;
    mpuAccelRange = map[Signals.configMPU9X50AccelRange]!.float!;
    bmpX80PressResolution = map[Signals.configBMPX80PressResolution]!.text!;
    gsrRange = map[Signals.configGSRRange]!.range!;
    var isSetExpBoardPower = map[Signals.configExpansionBoardInternalPower]!.isSet!;
    deviceConfiguration[MessageCodes.expansionBoardInternalPower] = [
      Signal(
        Signals.expansionBoardInternalPowerResponse,
        isSet: isSetExpBoardPower,
        rawValue: isSetExpBoardPower ? 1 : 0,
      ),
    ];
    var (bSize, signalsList) = map[Signals.dataSignalsOrderResponse]!.dataSignals!;
    bufferSize = bSize;
    signalsList.insert(0, Signals.dataTimestamp);
    dataSignals = signalsList;
    dataPacketByteSize = 1; // Counting in MessageCodes.dataPacket(0x00) length at the first byte position
    dataPacketByteSize += dataSignals.fold<int>(0, (acc, signal) => signal.type.byteSize + acc);
    return true;
  }

  Future<bool> initialize(List<Sensors> sensors, {sampleRate = 100}) async {
    return _commMutex.protect<bool>(() async {
      int byte0, byte1, byte2;
      bool success = false;
      flushCommandReplies();
      // await stopStreaming();

      // Set up sensors
      int configuration = 0;
      enabledSensors = sensors;
      for (var sensor in sensors) {
        configuration += 1 << sensor.enableBitShift;
      }
      byte0 = (configuration & 0x00ff0000) >> 16;
      byte1 = (configuration & 0x0000ff00) >> 8;
      byte2 = (configuration & 0x000000ff);

      (success, _) = await sendCommand("set up sensors", MessageCodes.setSensors, data: [byte0, byte1, byte2]);
      if (!success) return false;

      // Enable expansion board internal power
      (success, _) = await sendCommand(
        "enable expansion board power",
        MessageCodes.setExpansionBoardInternalPower,
        data: [1],
      );
      if (!success) return false;

      // Set sampling rate
      int clockWait = ((1 << 15) / sampleRate).toInt();
      byte0 = (clockWait & 0x00ff);
      byte1 = (clockWait & 0xff00) >> 8;
      (success, _) = await sendCommand("set up sampling rate", MessageCodes.setSamplingRate, data: [byte0, byte1]);
      if (!success) return false;

      success = await getDeviceConfiguration();
      if (!success) {
        debugPrint("Failed to get device configuration");
        return false;
      }

      realWorldClock = DateTime.now();
      SensorData.configurationTimestampMs = realWorldClock!.millisecondsSinceEpoch;
      var shimmer3ClockTicks = (realWorldClock!.millisecondsSinceEpoch * 32.768).truncate();
      var byteStream = ByteData(8);
      byteStream.setUint64(0, shimmer3ClockTicks, Endian.little);
      (success, _) = await sendCommand(
        "set up real world time",
        MessageCodes.setUnixTimestampMilliseconds,
        data: byteStream.buffer.asUint8List().toList(),
      );
      if (!success) return false;

      return true;
    });
  }

  Future<bool> startStreaming() async {
    return _commMutex.protect<bool>(() async {
      var (success, _) = await sendCommand("starting streaming", MessageCodes.startStreaming);
      if (!success) {
        return false;
      }
      _streaming = true;
      return true;
    });
  }

  Future<bool> stopStreaming() async {
    var (success, _) = await sendCommand("stopping streaming", MessageCodes.stopStreaming);
    if (!success) {
      return false;
    }
    _streaming = false;
    return true;
  }
}
