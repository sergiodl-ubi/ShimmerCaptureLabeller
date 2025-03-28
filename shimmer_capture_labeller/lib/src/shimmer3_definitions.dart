import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';
import '../tools/logging.dart';

DebugPrintCallback debugPrint = customDebugPrint("Shimmer3Definitions", true);

// ########### Shimmer3 BT Protocol ##########

const shimmer3ByteStringMaxLength = 255;

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
  fwVersion(
    0x2F,
    responseSignals: [
      Signals.fwVersionIDResponse,
      Signals.fwMajorResponse,
      Signals.fwMinorResponse,
      Signals.fwRCResponse,
    ],
  ),
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
  final List<Signals>? responseSignals;

  const MessageCodes(this.value, {this.responseSignals});

  Uint8List asUint8List() => Uint8List.fromList([value]);

  bool sameAsMessage(Uint8List msg) => msg.length == 1 && msg.single.toInt() == value;

  /// This Map can be used as a dictionary to lookup a MessageCode by it's raw value
  static Map<int, MessageCodes> asDictionaryMap() {
    Map<int, MessageCodes> dictionary = {};
    for (var code in MessageCodes.values) {
      dictionary[code.value] = code;
    }
    return dictionary;
  }
}

enum SignalIntTypes {
  u8(1, Endian.big),
  i8(1, Endian.big),
  u12l(2, Endian.little),
  u12b(2, Endian.big),
  i12l(2, Endian.little),
  i12b(2, Endian.big),
  u16l(2, Endian.little),
  u16b(2, Endian.big),
  i16l(2, Endian.little),
  i16b(2, Endian.big),
  u24l(3, Endian.little),
  u24b(3, Endian.big),
  i24l(3, Endian.little),
  i24b(3, Endian.big),
  u32l(4, Endian.little),
  u32b(4, Endian.big),
  i32l(4, Endian.little),
  i32b(4, Endian.big),
  u64l(8, Endian.little),
  u64b(8, Endian.big),
  i64l(8, Endian.little),
  i64b(8, Endian.big);

  final int byteSize;
  final Endian endianness;

  const SignalIntTypes(this.byteSize, this.endianness);

  @override
  String toString() => name;
}

class Signal {
  final Signals type;
  late SignalIntTypes intType;
  late String name;
  late int? value;
  late String? text;
  late ByteData blob;

  Signal(this.type, {this.value, this.text}) {
    intType = type.type;
    name = type.name;
    if (text != null) {
      blob = getBlob
    }
  }

  Signal fromByteData(Signals type, ByteData byteData) {
    if (type.processingMethod == ProcessingMethods.ascii) {
      text = getStringFromBlob(byteData);
      return Signal(type, text: text);
    }
    value = getIntFromBlob(intType, byteData, 0);
    return Signal(type, value: value);
  }

  @override
  String toString() => "($intType) $name signal (${text?.isNotEmpty ?? false ? text : value})";

  static int getIntFromBlob(SignalIntTypes intType, ByteData blob, idx) {
    switch (intType) {
      case SignalIntTypes.u8:
        return blob.getUint8(idx);
      case SignalIntTypes.i8:
        return blob.getInt8(idx);
      case SignalIntTypes.u12l:
      case SignalIntTypes.u12b:
      case SignalIntTypes.u16l:
      case SignalIntTypes.u16b:
        return blob.getUint16(idx, intType.endianness);
      case SignalIntTypes.i12l:
      case SignalIntTypes.i12b:
      case SignalIntTypes.i16l:
      case SignalIntTypes.i16b:
        return blob.getInt16(idx, intType.endianness);
      case SignalIntTypes.u24l:
      case SignalIntTypes.u24b:
      case SignalIntTypes.u32l:
      case SignalIntTypes.u32b:
        return blob.getUint32(idx, intType.endianness);
      case SignalIntTypes.i24l:
      case SignalIntTypes.i24b:
      case SignalIntTypes.i32l:
      case SignalIntTypes.i32b:
        return blob.getInt32(idx, intType.endianness);
      case SignalIntTypes.u64l:
      case SignalIntTypes.u64b:
        return blob.getUint64(idx, intType.endianness);
      case SignalIntTypes.i64l:
      case SignalIntTypes.i64b:
        return blob.getInt64(idx, intType.endianness);
    }
  }

  static ByteData getBlobFromInt(SignalIntTypes intType, int value) {
    var blob = ByteData(intType.byteSize);
    switch (intType) {
      case SignalIntTypes.u8:
        blob.setUint8(0, value);
        break;
      case SignalIntTypes.i8:
        blob.setInt8(0, value);
        break;
      case SignalIntTypes.u12l:
      case SignalIntTypes.u12b:
      case SignalIntTypes.u16l:
      case SignalIntTypes.u16b:
        blob.setUint16(0, value, intType.endianness);
        break;
      case SignalIntTypes.i12l:
      case SignalIntTypes.i12b:
      case SignalIntTypes.i16l:
      case SignalIntTypes.i16b:
        blob.setInt16(0, value, intType.endianness);
        break;
      case SignalIntTypes.u24l:
      case SignalIntTypes.u24b:
      case SignalIntTypes.u32l:
      case SignalIntTypes.u32b:
        blob.setUint32(0, value, intType.endianness);
        break;
      case SignalIntTypes.i24l:
      case SignalIntTypes.i24b:
      case SignalIntTypes.i32l:
      case SignalIntTypes.i32b:
        blob.setInt32(0, value, intType.endianness);
        break;
      case SignalIntTypes.u64l:
      case SignalIntTypes.u64b:
        blob.setUint64(0, value, intType.endianness);
        break;
      case SignalIntTypes.i64l:
      case SignalIntTypes.i64b:
        blob.setInt64(0, value, intType.endianness);
        break;
    }
    return blob;
  }

  static String getStringFromBlob(ByteData blob) {
    var length = blob.getUint8(0);
    var packetStringLength = blob.lengthInBytes - 1;
    if (length > packetStringLength) {
      debugPrint(
        "String length found in idx(0) of response packet ($length) is"
        " longer than information in response packet ($packetStringLength)",
      );
      length = packetStringLength;
    }
    var charBuffer = blob.buffer.asUint8List(1, length);
    return latin1.decode(charBuffer.toList(), allowInvalid: true);
  }

  static ByteData getBlobFromString(String text) {
    if (text.length > shimmer3ByteStringMaxLength) {
      throw ArgumentError(
          "This string is too long (${text.length}) to be converted into a Shimmer3 compatible blob."
          " Shimmer3 ByteString Max Length = $shimmer3ByteStringMaxLength");
    }
    var b = BytesBuilder();
    b.addByte(text.length);
    b.add(latin1.encode(text));
    return b.toBytes().buffer.asByteData();
  }
}

enum ProcessingMethods { adc, imu, int, ascii, worldClock }

enum Signals {
  lowNoiseAccelX(SignalIntTypes.u12l, processingMethod: ProcessingMethods.imu, byteID: 0x00),
  lowNoiseAccelY(SignalIntTypes.u12l, processingMethod: ProcessingMethods.imu, byteID: 0x01),
  lowNoiseAccelZ(SignalIntTypes.u12l, processingMethod: ProcessingMethods.imu, byteID: 0x02),
  wideRangeAccelX(SignalIntTypes.i16l, processingMethod: ProcessingMethods.imu, byteID: 0x04),
  wideRangeAccelY(SignalIntTypes.i16l, processingMethod: ProcessingMethods.imu, byteID: 0x05),
  wideRangeAccelZ(SignalIntTypes.i16l, processingMethod: ProcessingMethods.imu, byteID: 0x06),
  gyroscopeX(SignalIntTypes.i16b, processingMethod: ProcessingMethods.imu, byteID: 0x0A),
  gyroscopeY(SignalIntTypes.i16b, processingMethod: ProcessingMethods.imu, byteID: 0x0B),
  gyroscopeZ(SignalIntTypes.i16b, processingMethod: ProcessingMethods.imu, byteID: 0x0C),
  magnetometerX(SignalIntTypes.i16l, processingMethod: ProcessingMethods.imu, byteID: 0x07),
  magnetometerY(SignalIntTypes.i16l, processingMethod: ProcessingMethods.imu, byteID: 0x08),
  magnetometerZ(SignalIntTypes.i16l, processingMethod: ProcessingMethods.imu, byteID: 0x09),
  gsrADC(SignalIntTypes.u16l, processingMethod: ProcessingMethods.adc, byteID: 0x1C),
  batteryADC(SignalIntTypes.u12l, processingMethod: ProcessingMethods.adc, byteID: 0x03),
  ppgADC(SignalIntTypes.u12l, processingMethod: ProcessingMethods.adc, byteID: 0x12),
  pressure(SignalIntTypes.u16b, processingMethod: ProcessingMethods.adc, byteID: 0x1a),
  temperature(SignalIntTypes.u24b, processingMethod: ProcessingMethods.adc, byteID: 0x1b),
  dataTimestamp(SignalIntTypes.u24b),
  fwVersionIDResponse(SignalIntTypes.u16l),
  fwMajorResponse(SignalIntTypes.u16l),
  fwMinorResponse(SignalIntTypes.u8),
  fwRCResponse(SignalIntTypes.u8);

  final SignalIntTypes type;
  final ProcessingMethods processingMethod;
  final int? byteID;

  const Signals(this.type, {this.processingMethod = ProcessingMethods.int, this.byteID});
}

const Set imuSensors = {Sensors.lowNoiseAccel, Sensors.wideRangeAccel, Sensors.gyroscope, Sensors.magnetometer};

enum Sensors {
  dataTimestamp(0, [Signals.dataTimestamp]),
  lowNoiseAccel(23, [Signals.lowNoiseAccelX, Signals.lowNoiseAccelY, Signals.lowNoiseAccelZ]),
  wideRangeAccel(12, [Signals.wideRangeAccelX, Signals.wideRangeAccelY, Signals.wideRangeAccelZ]),
  gyroscope(22, [Signals.gyroscopeX, Signals.gyroscopeY, Signals.gyroscopeZ]),
  magnetometer(21, [Signals.magnetometerX, Signals.magnetometerY, Signals.magnetometerZ]),
  gsr(18, [Signals.gsrADC]),
  battery(13, [Signals.batteryADC]),
  ppg(8, [Signals.ppgADC]),
  pressureTemp(2, [Signals.pressure, Signals.pressure]);

  final int enableBitShift;
  final List<Signals> signals;

  const Sensors(this.enableBitShift, this.signals);

  @override
  String toString() => name;

  int getPacketSize() => signals.fold(0, (acc, signal) => acc + signal.type.byteSize);
}

// ########### Device Parameters ##########

enum ExpansionBoards {
  bridgeAmplifierPlus(0x08),
  gsrPlus(0x0E),
  shimmer3(0x1F),
  proto3Mini(0x24),
  exg(0x25),
  proto3Deluxe(0x26),
  highGAccel(0x2C),
  gps(0x2E),
  exgUnified(0x2F),
  gsrUnified(0x30),
  bridgeAmpUnified(0x31),
  shimmer3EXGExtended(0x3B);

  final int id;

  const ExpansionBoards(this.id);
}

// ########### Sensors default calibration values ##########

class IMUCalibrationData {
  final List<double> _offset;
  final List<double> _sensitivity;
  final List<double> _alignment;

  const IMUCalibrationData(List<double> offset3, List<double> sensitivity3x3, List<double> alignment3x3)
    : _offset = offset3,
      _sensitivity = sensitivity3x3,
      _alignment = alignment3x3;

  Vector3 get offset => Vector3.array(_offset);

  Matrix3 get sensitivity => Matrix3.fromList(_sensitivity);

  Matrix3 get alignment => Matrix3.fromList(_alignment);
}

class BMP280CalibrationData {
  final int t1, t2, t3;
  final int p1, p2, p3, p4, p5, p6, p7, p8, p9;

  const BMP280CalibrationData({
    this.t1 = 27504,
    this.t2 = 26435,
    this.t3 = -1000,
    this.p1 = 36477,
    this.p2 = -10685,
    this.p3 = 3024,
    this.p4 = 2855,
    this.p5 = 140,
    this.p6 = -7,
    this.p7 = 15500,
    this.p8 = -14600,
    this.p9 = 6000,
  });
}

enum IMUDefaultCalibrations {
  lowNoiseAccelKXRB52042(
    IMUCalibrationData([2047, 2047, 2047], [83, 0, 0, 0, 83, 0, 0, 0, 83], [0, -1, 0, -1, 0, 0, 0, 0, -1]),
  ),
  lowNoiseAccelKXTC92050(
    IMUCalibrationData([2053, 2053, 2053], [92, 0, 0, 0, 92, 0, 0, 0, 92], [0, -1, 0, -1, 0, 0, 0, 0, -1]),
  ),
  wideRangeAccelLSM303DLHC_2G(
    IMUCalibrationData([0, 0, 0], [1631, 0, 0, 0, 1631, 0, 0, 0, 1631], [-1, 0, 0, 0, 1, 0, 0, 0, -1]),
  ),
  wideRangeAccelLSM303DLHC_4G(
    IMUCalibrationData([0, 0, 0], [815, 0, 0, 0, 815, 0, 0, 0, 815], [-1, 0, 0, 0, 1, 0, 0, 0, -1]),
  ),
  wideRangeAccelLSM303DLHC_8G(
    IMUCalibrationData([0, 0, 0], [408, 0, 0, 0, 408, 0, 0, 0, 408], [-1, 0, 0, 0, 1, 0, 0, 0, -1]),
  ),
  wideRangeAccelLSM303DLHC_16G(
    IMUCalibrationData([0, 0, 0], [135, 0, 0, 0, 135, 0, 0, 0, 135], [-1, 0, 0, 0, 1, 0, 0, 0, -1]),
  ),
  wideRangeAccelLSM303AHTR_2G(
    IMUCalibrationData([0, 0, 0], [1671, 0, 0, 0, 1671, 0, 0, 0, 1671], [0, -1, 0, 1, 0, 0, 0, 0, -1]),
  ),
  wideRangeAccelLSM303AHTR_4G(
    IMUCalibrationData([0, 0, 0], [836, 0, 0, 0, 836, 0, 0, 0, 836], [0, -1, 0, 1, 0, 0, 0, 0, -1]),
  ),
  wideRangeAccelLSM303AHTR_8G(
    IMUCalibrationData([0, 0, 0], [418, 0, 0, 0, 418, 0, 0, 0, 418], [0, -1, 0, 1, 0, 0, 0, 0, -1]),
  ),
  wideRangeAccelLSM303AHTR_16G(
    IMUCalibrationData([0, 0, 0], [209, 0, 0, 0, 209, 0, 0, 0, 209], [0, -1, 0, 1, 0, 0, 0, 0, -1]),
  ),
  gyroscopeMPU910_250DPS(
    IMUCalibrationData([0, 0, 0], [131, 0, 0, 0, 131, 0, 0, 0, 131], [0, -1, 0, -1, 0, 0, 0, 0, -1]),
  ),
  gyroscopeMPU910_500DPS(
    IMUCalibrationData([0, 0, 0], [65.5, 0, 0, 0, 65.5, 0, 0, 0, 65.5], [0, -1, 0, -1, 0, 0, 0, 0, -1]),
  ),
  gyroscopeMPU910_1000DPS(
    IMUCalibrationData([0, 0, 0], [32.8, 0, 0, 0, 32.8, 0, 0, 0, 32.8], [0, -1, 0, -1, 0, 0, 0, 0, -1]),
  ),
  gyroscopeMPU910_2000DPS(
    IMUCalibrationData([0, 0, 0], [16.4, 0, 0, 0, 16.4, 0, 0, 0, 16.4], [0, -1, 0, -1, 0, 0, 0, 0, -1]),
  ),
  magnetometerLSM303DLHC_1_3Ga(
    IMUCalibrationData([0, 0, 0], [1100, 0, 0, 0, 1100, 0, 0, 0, 1100], [-1, 0, 0, 0, 1, 0, 0, 0, -1]),
  ),
  magnetometerLSM303DLHC_1_9Ga(
    IMUCalibrationData([0, 0, 0], [855, 0, 0, 0, 855, 0, 0, 0, 855], [-1, 0, 0, 0, 1, 0, 0, 0, -1]),
  ),
  magnetometerLSM303DLHC_2_5Ga(
    IMUCalibrationData([0, 0, 0], [670, 0, 0, 0, 670, 0, 0, 0, 670], [-1, 0, 0, 0, 1, 0, 0, 0, -1]),
  ),
  magnetometerLSM303DLHC_4_0Ga(
    IMUCalibrationData([0, 0, 0], [450, 0, 0, 0, 450, 0, 0, 0, 450], [-1, 0, 0, 0, 1, 0, 0, 0, -1]),
  ),
  magnetometerLSM303DLHC_4_7Ga(
    IMUCalibrationData(
      [0, 0, 0],
      [400, 0, 0, 0, 400, 0, 0, 0, 400], // Taken from LSM303DLHC datasheet
      [-1, 0, 0, 0, 1, 0, 0, 0, -1],
    ),
  ),
  magnetometerLSM303DLHC_5_6Ga(
    IMUCalibrationData([0, 0, 0], [330, 0, 0, 0, 330, 0, 0, 0, 330], [-1, 0, 0, 0, 1, 0, 0, 0, -1]),
  ),
  magnetometerLSM303DLHC_8_1Ga(
    IMUCalibrationData([0, 0, 0], [230, 0, 0, 0, 230, 0, 0, 0, 230], [-1, 0, 0, 0, 1, 0, 0, 0, -1]),
  ),
  magnetometerLSM303AHTR_49Ga(
    IMUCalibrationData([0, 0, 0], [667, 0, 0, 0, 667, 0, 0, 0, 667], [0, -1, 0, 1, 0, 0, 0, 0, -1]),
  );

  final IMUCalibrationData vectors;

  const IMUDefaultCalibrations(this.vectors);
}

// ########### Sensors Parameters ##########

// Units: Ohms, Default: 4 - Auto
const Map<int, int> gsrRangeResistor = {0: 40200, 1: 287000, 2: 1000000, 3: 3300000};

const Map<int, (double, double)> gsrResistanceRange = {
  0: (8000, 63000),
  1: (63000, 220000),
  2: (220000, 680000),
  3: (680000, 4700000),
};

// Units: bauds per second
const Map<int, int> btBaudRate = {
  0x00: 115200,
  0x01: 1200,
  0x02: 2400,
  0x03: 4800,
  0x04: 9600,
  0x05: 19200,
  0x06: 38400,
  0x07: 57600,
  0x08: 230400,
  0x09: 460800,
  0x0A: 921600,
  0x0B: 1000000,
};

// Units: dps, Default: 0 - ±250dps
const Map<int, int> mpu9X50GyroRange = {0: 250, 1: 500, 2: 1000, 3: 20000};

// Default: 0 - Low pressure resolution
const Map<int, String> bmpX80PressResolution = {0: "Low", 1: "Standard", 2: "High", 3: "Very High"};

// Units: Hz (with decimals for compatibility purposes with LSM303DLHC version)
// Default: 3 - 100.0Hz
const Map<int, double> lsm303AHTRMagDataRate = {0: 10.0, 1: 20.0, 2: 50.0, 3: 100.0};

// Units: Ga
const Map<int, double> lsm303AHTRMagRange = {0: 49.152};

// Units: g, Default: 0 - ±2.0g
const Map<int, double> lsm303AHTRAccelRange = {0: 2.0, 1: 16.0, 2: 4.0, 3: 8.0};

// Default: 4 - 100.0Hz
const Map<int, double> lsm303AHTRAccelDataRate = {
  0x00: 0, // Off
  0x01: 12.5,
  0x02: 25.0,
  0x03: 50.0,
  0x04: 100.0,
  0x05: 200.0,
  0x06: 400.0,
  0x07: 800.0,
  0x08: 1600.0,
  0x09: 3200.0,
  0x0A: 6400.0,
};

// Value of the two most significant bits: (XX00 0000)
const Map<int, String> chargingStatus = {
  0x00: "Not Charging",
  0x40: "Full Charge",
  0x80: "Conditioning", // No idea what is conditioning, maybe "Charging"?
  0xC0: "Bad Battery",
};
