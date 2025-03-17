import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';

/// True if sensitivity matrix is diagonal and alignment matrix follows:
/// [  0, -1,  0 ]
/// [ s1,  0,  0 ]  "s" represents a positive or negative sign
/// [  0,  0, -1 ]
///
/// This is true for Shimmer3 GSR+ default calibration values
const optimizedCalibration = true;
const Set imuSensors = {
  Sensors.lowNoiseAccel,
  Sensors.wideRangeAccel,
  Sensors.gyroscope,
  Sensors.magnetometer,
};

enum MessageCodes {
  // Stream and Logging
  dataPacket(0x00),
  startStreaming(0x07),
  stopStreaming(0x20),
  bufferSize(0x35),
  getBufferSize(0x36),
  startLogAndStream(0x70),
  status(0x71),
  getStatus(0x72),
  instreamCommand(0x8A),
  startLogging(0x92),
  stopLogging(0x93),
  batteryVoltage(0x94),
  getBatteryVoltage(0x95),
  stopLogAndStream(0x97),
  updateLoggingConfiguration(0x9C),
  setInstreamResponseACKPrefix(0xA3),
  setLogSync(0xE0),
  logSync(0xE1),

  // Device Configuration
  inquiryCommand(0x01),
  inquiryResponse(0x02),
  getSamplingRate(0x03),
  samplingRateResponse(0x04),
  setSamplingRate(0x05),
  toggleLED(0x06),
  setSensors(0x08),
  setConfigSetup(0x0E),
  configSetupResponse(0x0F),
  getConfigSetup(0x10),
  getAllCalibration(0x2C),
  allCalibration(0x2D),
  setChargeStatusLED(0x30),
  chargeStatusLED(0x31),
  getChargeStatusLED(0x32),
  resetToDefaultConfiguration(0x5A),
  resetCalibrationValue(0x5B),
  setExpansionBoardInternalPower(0x5E),
  expansionBoardInternalPower(0x5F),
  getExpansionBoardInternalPower(0x60),
  setEXGRegisters(0x61),
  exgRegisters(0x62),
  getEXGRegisters(0x63),
  setExpansionBoardMemory(0x67),
  expansionBoardMemory(0x68),
  getExpansionBoardMemory(0x69),
  setBluetoothBaudRate(0x6A),
  bluetoothBaudRate(0x6B),
  getBluetoothBaudRate(0x6C),
  setDerivedSignals(0x6D),
  derivedSignals(0x6E),
  getDerivedSignals(0x6F),
  directoryString(0x88),
  getDirectoryString(0x89),
  setCRC(0x8B),
  setInfoMem(0x8C),
  infoMem(0x8D),
  getInfoMem(0x8E),
  setUnixTimestampMilliseconds(0x8F),
  unixTimestampMilliseconds(0x90),
  getUnixTimestampMilliseconds(0x91),
  setCalibrationDump(0x98),
  calibrationDump(0x99),
  getCalibrationDump(0x9A),
  updateCalibrationDump(0x9B),

  // Experiment Setup Information
  setTrialConfig(0x73),
  trialConfig(0x74),
  getTrialConfig(0x75),
  setCenterString(0x76), // I guess this is "ResearchCenterName"
  centerString(0x77), // I guess this is "ResearchCenterName"
  getCenterString(0x78), // I guess this is "ResearchCenterName"
  setShimmerNameString(0x79),
  shimmerNameString(0x7a),
  getShimmerNameString(0x7b),
  setExperimentIDString(0x7c),
  experimentIDString(0x7d),
  getExperimentIDString(0x7e),
  setMyID(0x7F),
  myID(0x80),
  getMyID(0x81),
  setShimmerNumber(0x82),
  shimmerNumber(0x83),
  getShimmerNumber(0x84),
  setConfigTimestampString(0x85),
  configTimestampString(0x86),
  getConfigTimestampString(0x87),

  // Sensors configuration
  // "Wide-Range Accelerometer" or "Digital Accelerometer" sensor
  // Shimmer3 STMicro Sensor: before 2017-09 LSM303DLHC, after 2017-09 LSM303AHTR
  setLSM303DLHCAccelRange(0x09),
  lsm303DLHCAccelRange(0x0A),
  getLSM303DLHCAccelRange(0x0B),
  setLSM303DLHCAccelCalibration(0x1A),
  lsm303DLHCAccelCalibration(0x1B),
  getLSM303DLHCAccelCalibration(0x1C),
  setLSM303DLHCAccelSamplingRate(0x40),
  lsm303DLHCAccelSamplingRate(0x41),
  getLSM303DLHCAccelSamplingRate(0x42),
  setLSM303DLHCAccelLowPower(0x43),
  lsm303DLHCAccelLowPower(0x44),
  getLSM303DLHCAccelLowPower(0x45),
  setLSM303DLHCAccelHighResolution(0x46),
  lsm303DLHCAccelHighResolution(0x47),
  getLSM303DLHCAccelHighResolution(0x48),
  // "Magnetometer" sensor
  setLSM303DLHCMagCalibration(0x17),
  lsm303DLHCMagCalibration(0x18),
  getLSM303DLHCMagCalibration(0x19),
  setLSM303DLHCMagSamplingRate(0x3A),
  lsm303DLHCMagSamplingRate(0x3B),
  getLSM303DLHCMagSamplingRate(0x3C),
  setLSM303DLHCMagGain(0x37),
  lsm303DLHCMagGain(0x38),
  getLSM303DLHCMagGain(0x39),
  // "Low-Noise Accelerometer" sensor
  // Shimmer3 Kionix Sensor: before 2017-09 KXRB5-2042, after 2017-09 KXTC9-2050
  setAnalogAccelCalibration(0x11),
  analogAccelCalibration(0x12),
  getAnalogAccelCalibration(0x13),
  // "Gyroscope" sensor
  // Shimmer3 Invensense Sensor: before 2017-09 MPU9150, after 2017-09 MPU9250
  setMPU9150GyroRange(0x49),
  mpu9150GyroRange(0x4A),
  getMPU9150GyroRange(0x4B),
  setMPU9150GyroCalibration(0x14),
  mpu9150GyroCalibration(0x15),
  getMPU9150GyroCalibration(0x16),
  setMPU9150SamplingRate(0x4C),
  mpu9150SamplingRate(0x4D),
  getMPU9150SamplingRate(0x4E),
  setMPU9150AccelRange(0x4F),
  mpu9150AccelRange(0x50),
  getMPU9150AccelRange(0x51),
  mpu9150MagSensorADJVals(0x5C),
  getMPU9150MagSensorADJVals(0x5D),
  // "GSR" sensor
  setGSRRange(0x21),
  gsrRange(0x22),
  getGSRRange(0x23),
  // "Pressure and Temperature" sensor
  // Shimmer3 Bosch Sensor: before 2017-09 BMP180, after 2017-09 BMP280
  setBMPX80PressOversamplingRatio(0x52),
  bmpX80PressOversamplingRatio(0x53),
  getBMPX80PressOversamplingRatio(0x54),
  bmp180CalibrationCoefficients(0x58),
  getBMP180CalibrationCoefficients(0x59),
  bmp280CalibrationCoefficients(0x9F),
  getBMP280CalibrationCoefficients(0xA0),

  // Device Information
  deviceVersion(0x25),
  getFWVersion(0x2E),
  fwVersion(0x2F),
  uniqueSerial(0x3D),
  getUniqueSerial(0x3E),
  getDeviceVersion(0x3F),
  setExpansionBoardID(0x64),
  expansionBoardID(0x65),
  getExpansionBoardID(0x66),
  dummyCommand(0x96),
  getBluetoothVersionString(0xA1),
  bluetoothVersionString(0xA2),

  acknowledged(0xFF);

  final int value;
  const MessageCodes(this.value);
  Uint8List asUint8List() => Uint8List.fromList([value]);
  bool sameAsMessage(Uint8List msg) =>
      msg.length == 1 && msg.single.toInt() == value;
}

enum SignalTypes {
  u8("Uint8", 1, Endian.big),
  i8("int8", 1, Endian.big),
  u12l("Uint16", 2, Endian.little),
  u12b("Uint16", 2, Endian.big),
  i12l("int16", 2, Endian.little),
  i12b("int16", 2, Endian.big),
  u16l("Uint16", 2, Endian.little),
  u16b("Uint16", 2, Endian.big),
  i16l("int16", 2, Endian.little),
  i16b("int16", 2, Endian.big),
  u24l("Uint32", 3, Endian.little),
  u24b("Uint32", 3, Endian.big),
  i24l("int32", 3, Endian.little),
  i24b("int32", 3, Endian.big),
  u32l("Uint32", 4, Endian.little),
  u32b("Uint32", 4, Endian.big),
  i32l("int32", 4, Endian.little),
  i32b("int32", 4, Endian.big),
  u64l("Uint64", 8, Endian.little),
  u64b("Uint64", 8, Endian.big),
  i64l("int64", 8, Endian.little),
  i64b("int64", 8, Endian.big);

  final String intType;
  final int byteSize;
  final Endian endianness;
  const SignalTypes(this.intType, this.byteSize, this.endianness);
  @override
  String toString() => name;
}

class Signal {
  final String name;
  final SignalTypes type;
  final int? byteID;
  const Signal(this.name, this.type, {this.byteID});
  @override
  String toString() => "($type) $name signal (ID:$byteID)";
}

/// A collection of [Signal]'s data of one of Shimmer3's [Sensors].
///
/// If provided, this implementation will store the `Uint8List` stream of bytes
/// in [dataPacket] of a specified [sensorType] and it will automatically parse
/// each of its defined [Signal]'s into their raw integer values.
///
/// If [calibrationVectors] are provided, each signal can be processed into their
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
  /// Calibration follows [alignment]^(-1) . [sensitivity]^(-1) . ([rawData] - [offset])
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

enum Sensors {
  dataTimestamp(0, [
    Signal("Timestamp", SignalTypes.u24b),
  ]),
  lowNoiseAccel(23, [
    Signal("X", SignalTypes.u12l, byteID: 0x00),
    Signal("Y", SignalTypes.u12l, byteID: 0x01),
    Signal("Z", SignalTypes.u12l, byteID: 0x02),
  ]),
  wideRangeAccel(12, [
    Signal("X", SignalTypes.i16l, byteID: 0x04),
    Signal("Y", SignalTypes.i16l, byteID: 0x05),
    Signal("Z", SignalTypes.i16l, byteID: 0x06),
  ]),
  gyroscope(22, [
    Signal("X", SignalTypes.i16b, byteID: 0x0a),
    Signal("Y", SignalTypes.i16b, byteID: 0x0b),
    Signal("Z", SignalTypes.i16b, byteID: 0x0c),
  ]),
  magnetometer(21, [
    Signal("X", SignalTypes.i16l, byteID: 0x07),
    Signal("Y", SignalTypes.i16l, byteID: 0x08),
    Signal("Z", SignalTypes.i16l, byteID: 0x09),
  ]),
  gsr(18, [
    Signal("GSR", SignalTypes.u16l, byteID: 0x1c),
  ]),
  battery(13, [
    Signal("Voltage", SignalTypes.u12l, byteID: 0x03),
  ]),
  ppg(8, [
    Signal("PPG", SignalTypes.u12l, byteID: 0x12),
  ]),
  pressureTemp(2, [
    Signal("Temp", SignalTypes.u16b, byteID: 0x1a),
    Signal("Press", SignalTypes.u24b, byteID: 0x1b),
  ]);

  final int enableBitShift;
  final List<Signal> signals;
  const Sensors(this.enableBitShift, this.signals);
  @override
  String toString() => name;

  int getPacketSize() =>
      signals.fold(0, (acc, signal) => acc + signal.type.byteSize);
}
