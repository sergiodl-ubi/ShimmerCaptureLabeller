import 'package:flutter/foundation.dart';

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
  const Signal(this.name, this.type);
}

class SensorData {
  final Sensors type;
  late Uint8List dataPacket;
  Map<String, int> rawData = {};
  Map<String, int> data = {};

  SensorData(this.type, {Uint8List? dataPacket}) {
    var dataSize = type.getPacketSize();
    if (dataPacket == null) {
      this.dataPacket = Uint8List(dataSize);
      for (var signal in type.signals) {
        rawData[signal.name] = 0;
        data[signal.name] = 0;
      }
    } else if (dataPacket.length == dataSize) {
      this.dataPacket = dataPacket;
      rawData = parseDataPacket(dataPacket);
    } else {
      throw Exception("packet length (${dataPacket.length} is not the same as"
          " Sensor type ($type) length (${type.getPacketSize()})");
    }
  }

  Map<String, int> parseDataPacket(Uint8List dataPacket) {
    Map<String, int> parsedData = {};
    var idx = 0;
    var blob = ByteData.sublistView(dataPacket);
    for (var signal in type.signals) {
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
}

enum Sensors {
  lowNoiseAccel(23, [
    Signal("X", SignalTypes.u12l),
    Signal("Y", SignalTypes.u12l),
    Signal("Z", SignalTypes.u12l),
  ]),
  wideRangeAccel(12, [
    Signal("X", SignalTypes.i16l),
    Signal("Y", SignalTypes.i16l),
    Signal("Z", SignalTypes.i16l),
  ]),
  gyroscope(22, [
    Signal("X", SignalTypes.i16b),
    Signal("Y", SignalTypes.i16b),
    Signal("Z", SignalTypes.i16b),
  ]),
  magnetometer(21, [
    Signal("X", SignalTypes.i16l),
    Signal("Y", SignalTypes.i16l),
    Signal("Z", SignalTypes.i16l),
  ]),
  gsr(18, [
    Signal("Raw", SignalTypes.u16l),
  ]),
  battery(13, [
    Signal("Raw", SignalTypes.u12l),
  ]),
  ppg(8, [
    Signal("Raw", SignalTypes.u12l),
  ]),
  pressureTemp(2, [
    Signal("Temp", SignalTypes.u16b),
    Signal("Press", SignalTypes.u24b),
  ]);

  final int enableBitShift;
  final List<Signal> signals;
  const Sensors(this.enableBitShift, this.signals);
  @override
  String toString() => name;

  int getPacketSize() =>
      signals.fold(0, (acc, signal) => acc + signal.type.byteSize);
}
