import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math.dart';
import '../tools/logging.dart';

DebugPrintCallback debugPrint = customDebugPrint("Shimmer3Definitions", true);

// ########### Shimmer3 BT Protocol ##########

const shimmer3ByteStringMaxLength = 255;
const deviceVoltageDropFactor = 1.988;
Map<int, MessageCodes> messageCodesDictionary = MessageCodes.asDictionaryMap();

enum MessageCodes {
  // Stream and Logging
  dataPacket(0x00),
  startStreaming(0x07),
  stopStreaming(0x20),
  bufferSize(0x35),
  getBufferSize(0x36),
  startLogAndStream(0x70),
  status(
    0x71,
    responseSignals: [
      Signals.statusBTStreamResponse,
      Signals.statusSDLogResponse,
      Signals.statusSensingResponse,
      Signals.statusDockedResponse,
    ],
  ),
  getStatus(0x72),
  instreamCommand(0x8A, responseSignals: [Signals.statusCodeResponse]),
  startLogging(0x92),
  stopLogging(0x93),
  batteryVoltage(0x94, responseSignals: [Signals.batteryVoltageResponse, Signals.chargeStatusLEDResponse]),
  getBatteryVoltage(0x95),
  stopLogAndStream(0x97),
  updateLoggingConfiguration(0x9C),
  setInstreamResponseACKPrefix(0xA3),
  setLogSync(0xE0),
  logSync(0xE1),

  // Device Configuration
  inquiryCommand(0x01),
  inquiryResponse(
    0x02,
    responseSignals: [
      Signals.samplingRateResponse,
      Signals.configLSM303AccelSamplingRate,
      Signals.configLSM303AccelRange,
      Signals.configLSM303AccelLowPower,
      Signals.configLSM303AccelHighRes,
      Signals.configMPU9X50SamplingRate,
      Signals.configLSM303MagGain,
      Signals.configLSM303MagSamplingRate,
      Signals.configMPU9X50GyroRange,
      Signals.configMPU9X50AccelRange,
      Signals.configBMPX80PressResolution,
      Signals.configGSRRange,
      Signals.configExpansionBoardInternalPower,
      Signals.dataSignalsOrderResponse,
    ],
  ),
  getSamplingRate(0x03),
  samplingRateResponse(0x04, responseSignals: [Signals.samplingRateResponse]),
  setSamplingRate(0x05),
  toggleLED(0x06),
  setSensors(0x08),
  setConfigSetup(0x0E),
  configSetupResponse(0x0F),
  getConfigSetup(0x10),
  getAllCalibration(0x2C),
  allCalibration(
    0x2D,
    responseSignals: [
      Signals.analogAccelOffsetX,
      Signals.analogAccelOffsetY,
      Signals.analogAccelOffsetZ,
      Signals.analogAccelSensitivityX,
      Signals.analogAccelSensitivityY,
      Signals.analogAccelSensitivityZ,
      Signals.analogAccelAlignRow1ColA,
      Signals.analogAccelAlignRow1ColB,
      Signals.analogAccelAlignRow1ColC,
      Signals.analogAccelAlignRow2ColA,
      Signals.analogAccelAlignRow2ColB,
      Signals.analogAccelAlignRow2ColC,
      Signals.analogAccelAlignRow3ColA,
      Signals.analogAccelAlignRow3ColB,
      Signals.analogAccelAlignRow3ColC,
      Signals.gyroscopeOffsetX,
      Signals.gyroscopeOffsetY,
      Signals.gyroscopeOffsetZ,
      Signals.gyroscopeSensitivityX,
      Signals.gyroscopeSensitivityY,
      Signals.gyroscopeSensitivityZ,
      Signals.gyroscopeAlignRow1ColA,
      Signals.gyroscopeAlignRow1ColB,
      Signals.gyroscopeAlignRow1ColC,
      Signals.gyroscopeAlignRow2ColA,
      Signals.gyroscopeAlignRow2ColB,
      Signals.gyroscopeAlignRow2ColC,
      Signals.gyroscopeAlignRow3ColA,
      Signals.gyroscopeAlignRow3ColB,
      Signals.gyroscopeAlignRow3ColC,
      Signals.magnetometerOffsetX,
      Signals.magnetometerOffsetY,
      Signals.magnetometerOffsetZ,
      Signals.magnetometerSensitivityX,
      Signals.magnetometerSensitivityY,
      Signals.magnetometerSensitivityZ,
      Signals.magnetometerAlignRow1ColA,
      Signals.magnetometerAlignRow1ColB,
      Signals.magnetometerAlignRow1ColC,
      Signals.magnetometerAlignRow2ColA,
      Signals.magnetometerAlignRow2ColB,
      Signals.magnetometerAlignRow2ColC,
      Signals.magnetometerAlignRow3ColA,
      Signals.magnetometerAlignRow3ColB,
      Signals.magnetometerAlignRow3ColC,
      Signals.wrAccelOffsetX,
      Signals.wrAccelOffsetY,
      Signals.wrAccelOffsetZ,
      Signals.wrAccelSensitivityX,
      Signals.wrAccelSensitivityY,
      Signals.wrAccelSensitivityZ,
      Signals.wrAccelAlignRow1ColA,
      Signals.wrAccelAlignRow1ColB,
      Signals.wrAccelAlignRow1ColC,
      Signals.wrAccelAlignRow2ColA,
      Signals.wrAccelAlignRow2ColB,
      Signals.wrAccelAlignRow2ColC,
      Signals.wrAccelAlignRow3ColA,
      Signals.wrAccelAlignRow3ColB,
      Signals.wrAccelAlignRow3ColC,
    ],
  ),
  setChargeStatusLED(0x30),
  chargeStatusLED(0x31, responseSignals: [Signals.chargeStatusLEDResponse]),
  getChargeStatusLED(0x32),
  resetToDefaultConfiguration(0x5A),
  resetCalibrationValue(0x5B),
  setExpansionBoardInternalPower(0x5E),
  expansionBoardInternalPower(0x5F, responseSignals: [Signals.expansionBoardInternalPowerResponse]),
  getExpansionBoardInternalPower(0x60),
  setEXGRegisters(0x61),
  exgRegisters(0x62),
  getEXGRegisters(0x63),
  setExpansionBoardMemory(0x67),
  expansionBoardMemory(0x68),
  getExpansionBoardMemory(0x69),
  setBluetoothBaudRate(0x6A),
  bluetoothBaudRate(0x6B, responseSignals: [Signals.bluetoothBaudRateResponse]),
  getBluetoothBaudRate(0x6C),
  setDerivedSignals(0x6D),
  derivedSignals(0x6E),
  getDerivedSignals(0x6F),
  directoryString(0x88, responseSignals: [Signals.directoryStringResponse]),
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
  shimmerNameString(0x7a, responseSignals: [Signals.shimmerNameResponse]),
  getShimmerNameString(0x7b),
  setExperimentIDString(0x7c),
  experimentIDString(0x7d, responseSignals: [Signals.experimentIDResponse]),
  getExperimentIDString(0x7e),
  setMyID(0x7F),
  myID(0x80),
  getMyID(0x81),
  setShimmerNumber(0x82),
  shimmerNumber(0x83, responseSignals: [Signals.shimmerNumberResponse]),
  getShimmerNumber(0x84),
  setConfigTimestampString(0x85),
  configTimestampString(0x86, responseSignals: [Signals.configTimestampResponse]),
  getConfigTimestampString(0x87),

  // Sensors configuration
  // "Wide-Range Accelerometer" or "Digital Accelerometer" sensor
  // Shimmer3 STMicro Sensor: before 2017-09 LSM303DLHC, after 2017-09 LSM303AHTR
  setLSM303DLHCAccelRange(0x09),
  lsm303DLHCAccelRange(0x0A, responseSignals: [Signals.lsm303AHTRAccelRangeResponse]),
  getLSM303DLHCAccelRange(0x0B),
  setLSM303DLHCAccelCalibration(0x1A),
  lsm303DLHCAccelCalibration(0x1B),
  getLSM303DLHCAccelCalibration(0x1C),
  setLSM303DLHCAccelSamplingRate(0x40),
  lsm303DLHCAccelSamplingRate(0x41, responseSignals: [Signals.lsm303AHTRAccelDataRateResponse]),
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
  lsm303DLHCMagGain(0x38, responseSignals: [Signals.lsm303AHTRMagGainResponse]),
  getLSM303DLHCMagGain(0x39),
  // "Low-Noise Accelerometer" sensor
  // Shimmer3 Kionix Sensor: before 2017-09 KXRB5-2042, after 2017-09 KXTC9-2050
  setAnalogAccelCalibration(0x11),
  analogAccelCalibration(0x12),
  getAnalogAccelCalibration(0x13),
  // "Gyroscope" sensor
  // Shimmer3 InvenSense Sensor: before 2017-09 MPU9150, after 2017-09 MPU9250
  setMPU9X50GyroRange(0x49),
  mpu9X50GyroRange(0x4A, responseSignals: [Signals.mpu9X50GyroRangeResponse]),
  getMPU9X50GyroRange(0x4B),
  setMPU9X50GyroCalibration(0x14),
  mpu9X50GyroCalibration(0x15),
  getMPU9X50GyroCalibration(0x16),
  setMPU9X50SamplingRate(0x4C),
  mpu9X50SamplingRate(0x4D),
  getMPU9X50SamplingRate(0x4E),
  setMPU9X50AccelRange(0x4F),
  mpu9X50AccelRange(0x50),
  getMPU9X50AccelRange(0x51),
  mpu9X50MagSensorADJVals(0x5C),
  getMPU9X50MagSensorADJVals(0x5D),
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
  bmp280CalibrationCoefficients(
    0x9F,
    responseSignals: [
      Signals.bmp280CalibrationT1,
      Signals.bmp280CalibrationT2,
      Signals.bmp280CalibrationT3,
      Signals.bmp280CalibrationP1,
      Signals.bmp280CalibrationP2,
      Signals.bmp280CalibrationP3,
      Signals.bmp280CalibrationP4,
      Signals.bmp280CalibrationP5,
      Signals.bmp280CalibrationP6,
      Signals.bmp280CalibrationP7,
      Signals.bmp280CalibrationP8,
      Signals.bmp280CalibrationP9,
    ],
  ),
  getBMP280CalibrationCoefficients(0xA0),

  // Device Information
  deviceVersion(0x25, responseSignals: [Signals.devVersionResponse]),
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
  expansionBoardID(
    0x65,
    responseSignals: [
      Signals.expBoardIDLengthResponse,
      Signals.expBoardIDTypeResponse,
      Signals.expBoardIDRevisionResponse,
      Signals.expBoardIDSpeRevisionResponse,
    ],
  ),
  getExpansionBoardID(0x66),
  dummyCommand(0x96),
  getBluetoothVersionString(0xA1),
  bluetoothVersionString(0xA2, responseSignals: [Signals.bluetoothVersionResponse]),
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

  @override
  String toString() => name;
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
  i64b(8, Endian.big),
  noByteShift(0, Endian.little),
  byteShift(1, Endian.little);

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
  late int? integer;
  late String? text;
  late double? float;
  late bool? isSet;
  late ({double min, double max})? range;
  late (int, List<Signals>)? dataSignals;
  late MessageCodes? messageCode;
  int? rawValue;

  Signal(
    this.type, {
    this.integer,
    this.text,
    this.float,
    this.isSet,
    this.range,
    this.dataSignals,
    this.messageCode,
    this.rawValue,
  }) {
    intType = type.type;
    name = type.name;
    if (text != null && integer != null && float != null && isSet != null) {
      throw ArgumentError("You need to set at least one value type [integer, text, float, isSet, range, signalOrder]");
    }
  }

  @override
  String toString() {
    var stringValues = <String>[];
    var valuesToCheck = {
      "Integer": integer,
      "Text": text,
      "Double": float,
      "Boolean": isSet,
      "ValueRange": range,
      "DataSignals": dataSignals,
      "MessageCode": messageCode,
      "RawValue": rawValue,
    };
    for (var entry in valuesToCheck.entries) {
      if (entry.value != null) {
        stringValues.add("${entry.key}: ${entry.value}");
      }
    }
    return "($intType) $name signal values: (${stringValues.join(', ')})";
  }

  factory Signal.fromByteData(Signals signal, ByteData blob, {int idx = 0}) {
    int? integer, rawValue;
    double? float;
    String? text;
    bool? isSet;
    ({double min, double max})? range;
    (int, List<Signals>)? dataSignals;
    MessageCodes? messageCode;
    switch (signal.process) {
      case ProcessingMethods.ascii:
        text = getStringFromByteData(blob);
        break;
      case ProcessingMethods.valueMap:
        var mapKey = rawValue = getIntFromByteData(signal.type, blob, idx: idx);
        switch (signal) {
          case Signals.chargeStatusLEDResponse:
          case Signals.expBoardIDTypeResponse:
            text = signal.valueMap![mapKey];
            break;
          case Signals.lsm303AHTRAccelRangeResponse:
          case Signals.lsm303AHTRMagGainResponse:
          case Signals.lsm303AHTRAccelDataRateResponse:
            float = signal.valueMap![mapKey];
            break;
          case Signals.mpu9X50GyroRangeResponse:
          case Signals.bluetoothBaudRateResponse:
            integer = signal.valueMap![mapKey];
            break;
          default:
            debugPrint("WARNING: Signal ($signal) with valueMap has no parseDataFrame handler");
            break;
        }
        break;
      case ProcessingMethods.tickSamplingRate:
        var delayTicks = rawValue = getIntFromByteData(signal.type, blob, idx: idx);
        float = tickSamplingRate(delayTicks);
        break;
      case ProcessingMethods.bitShift:
        var registerValue = rawValue = getIntFromByteData(signal.type, blob, idx: idx);
        var trueValue = (registerValue & signal.bitMask!) >> signal.bitShift!;
        if (signal.valueMap != null) {
          // Multiple value bit shift with a value mapping
          switch (signal) {
            case Signals.configLSM303AccelRange:
            case Signals.configLSM303AccelSamplingRate:
            case Signals.configLSM303MagGain:
            case Signals.configLSM303MagSamplingRate:
            case Signals.configMPU9X50AccelRange:
              float = signal.valueMap![trueValue];
              break;
            case Signals.configMPU9X50GyroRange:
              integer = signal.valueMap![trueValue];
              break;
            case Signals.configBMPX80PressResolution:
              text = signal.valueMap![trueValue];
              break;
            case Signals.configGSRRange:
              range = signal.valueMap![trueValue];
              break;
            default:
              debugPrint("WARNING: Signal ($signal) with valueMap has no parseDataFrame handler");
              break;
          }
        } else {
          // Normal bit shift that represents an integer value or a boolean (bit set or unset)
          var bitMaskInBinary = signal.bitMask!.toRadixString(2);
          var bitsInMask = bitMaskInBinary.split("").fold<int>(0, (acc, char) => char == "1" ? acc + 1 : acc);
          var isBoolean = bitsInMask == 1;
          if (isBoolean) {
            isSet = trueValue != 0;
          } else {
            integer = trueValue;
          }
        }
        break;
      case ProcessingMethods.alignMatrix:
        rawValue = getIntFromByteData(signal.type, blob, idx: idx);
        integer = (rawValue / 100).truncate();
        break;
      case ProcessingMethods.messageCode:
        rawValue = getIntFromByteData(signal.type, blob, idx: idx);
        messageCode = messageCodesDictionary[rawValue]!;
        switch (messageCode) {
          case MessageCodes.directoryString:
            var textBlob = ByteData.sublistView(blob, idx + 1);
            text = getStringFromByteData(textBlob);
            break;
          case MessageCodes.status:
            rawValue = getIntFromByteData(SignalIntTypes.u8, blob, idx: idx + 1);
            break;
          case MessageCodes.batteryVoltage:
            rawValue = getIntFromByteData(SignalIntTypes.u24b, blob, idx: idx + 1);
            break;
          default:
            debugPrint("WARNING: Signal ($signal) does not implement $messageCode message code parsing");
            break;
        }
        break;
      case ProcessingMethods.mpuGyroSensitivity:
        rawValue = getIntFromByteData(signal.type, blob, idx: idx);
        float = rawValue / 100;
        break;
      case ProcessingMethods.mpuGyroDataRate:
        rawValue = getIntFromByteData(signal.type, blob, idx: idx);
        float = 8000 / (rawValue + 1); // Shimmer3 manual is wrong, MPU9250's manual says is +1 not -1
        break;
      case ProcessingMethods.boolean:
        rawValue = getIntFromByteData(signal.type, blob, idx: idx);
        isSet = rawValue != 0;
        break;
      case ProcessingMethods.signalOrder:
        dataSignals = getDataSignalsFromByteData(blob, idx: idx);
        break;
      case ProcessingMethods.batteryVoltage:
        var adcValue = rawValue = getIntFromByteData(signal.type, blob, idx: idx);
        float = (adcValue * 3 / 4095) * deviceVoltageDropFactor;
        break;
      case ProcessingMethods.int:
      default:
        integer = rawValue = getIntFromByteData(signal.type, blob, idx: idx);
        break;
    }
    return Signal(
      signal,
      text: text,
      integer: integer,
      float: float,
      isSet: isSet,
      range: range,
      dataSignals: dataSignals,
      messageCode: messageCode,
      rawValue: rawValue,
    );
  }

  static int getIntFromByteData(SignalIntTypes intType, ByteData byteData, {int idx = 0}) {
    switch (intType) {
      case SignalIntTypes.noByteShift:
      case SignalIntTypes.byteShift:
      case SignalIntTypes.u8:
        return byteData.getUint8(idx);
      case SignalIntTypes.i8:
        return byteData.getInt8(idx);
      case SignalIntTypes.u12l:
      case SignalIntTypes.u12b:
      case SignalIntTypes.u16l:
      case SignalIntTypes.u16b:
        return byteData.getUint16(idx, intType.endianness);
      case SignalIntTypes.i12l:
      case SignalIntTypes.i12b:
      case SignalIntTypes.i16l:
      case SignalIntTypes.i16b:
        return byteData.getInt16(idx, intType.endianness);
      case SignalIntTypes.u24l:
      case SignalIntTypes.u24b:
      case SignalIntTypes.u32l:
      case SignalIntTypes.u32b:
        return byteData.getUint32(idx, intType.endianness);
      case SignalIntTypes.i24l:
      case SignalIntTypes.i24b:
      case SignalIntTypes.i32l:
      case SignalIntTypes.i32b:
        return byteData.getInt32(idx, intType.endianness);
      case SignalIntTypes.u64l:
      case SignalIntTypes.u64b:
        return byteData.getUint64(idx, intType.endianness);
      case SignalIntTypes.i64l:
      case SignalIntTypes.i64b:
        return byteData.getInt64(idx, intType.endianness);
    }
  }

  static ByteData getByteDataFromInt(SignalIntTypes intType, int value) {
    var blob = ByteData(intType.byteSize);
    switch (intType) {
      case SignalIntTypes.noByteShift:
      case SignalIntTypes.byteShift:
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

  static String getStringFromByteData(ByteData byteData) {
    var length = byteData.getUint8(0);
    var packetStringLength = byteData.lengthInBytes - 1;
    if (length > packetStringLength) {
      debugPrint(
        "String length found in idx(0) of response packet ($length) is"
        " longer than information in response packet ($packetStringLength)",
      );
      length = packetStringLength;
    }
    var endingIdx = length + 1; // idx referenced from the original buffer that includes an extra length byte.
    var charBuffer = Uint8List.sublistView(byteData, 1, endingIdx);
    debugPrint("Char buffer extracted $charBuffer");
    return ascii.decode(charBuffer.toList(), allowInvalid: true);
  }

  static ByteData getByteDataFromString(String text) {
    if (text.length > shimmer3ByteStringMaxLength) {
      throw ArgumentError(
        "This string is too long (${text.length}) to be converted into a Shimmer3 compatible blob."
        " Shimmer3 ByteString Max Length = $shimmer3ByteStringMaxLength",
      );
    }
    var b = BytesBuilder();
    b.addByte(text.length);
    b.add(latin1.encode(text));
    return b.toBytes().buffer.asByteData();
  }

  static (int, List<Signals>) getDataSignalsFromByteData(ByteData byteData, {int idx = 0}) {
    List<Signals> signalsList = [];
    const headerSize = 2;
    var length = byteData.getUint8(idx);
    var bufferSize = byteData.getUint8(idx + 1);
    var signalsIdx = headerSize + idx;
    var packetStringLength = byteData.lengthInBytes - signalsIdx;
    if (length > packetStringLength) {
      debugPrint(
        "String length found in idx(0) of response packet ($length) is"
        " longer than information in response packet ($packetStringLength)",
      );
      length = packetStringLength;
    }
    for (int offset in Iterable.generate(length)) {
      var signalID = byteData.getUint8(signalsIdx + offset);
      signalsList.add(signalsIDDictionary[signalID]!);
    }
    return (bufferSize, signalsList);
  }
}

enum ProcessingMethods {
  adc,
  imu,
  int,
  ascii,
  clockShift,
  valueMap,
  messageCode,
  tickSamplingRate,
  bitShift,
  alignMatrix,
  mpuGyroSensitivity,
  mpuGyroDataRate,
  boolean,
  signalOrder,
  batteryVoltage,
}

enum Signals {
  lowNoiseAccelX(type: SignalIntTypes.u12l, process: ProcessingMethods.imu),
  lowNoiseAccelY(type: SignalIntTypes.u12l, process: ProcessingMethods.imu),
  lowNoiseAccelZ(type: SignalIntTypes.u12l, process: ProcessingMethods.imu),
  wideRangeAccelX(type: SignalIntTypes.i16l, process: ProcessingMethods.imu),
  wideRangeAccelY(type: SignalIntTypes.i16l, process: ProcessingMethods.imu),
  wideRangeAccelZ(type: SignalIntTypes.i16l, process: ProcessingMethods.imu),
  gyroscopeX(type: SignalIntTypes.i16b, process: ProcessingMethods.imu),
  gyroscopeY(type: SignalIntTypes.i16b, process: ProcessingMethods.imu),
  gyroscopeZ(type: SignalIntTypes.i16b, process: ProcessingMethods.imu),
  magnetometerX(type: SignalIntTypes.i16l, process: ProcessingMethods.imu),
  magnetometerY(type: SignalIntTypes.i16l, process: ProcessingMethods.imu),
  magnetometerZ(type: SignalIntTypes.i16l, process: ProcessingMethods.imu),
  gsrADC(type: SignalIntTypes.u16l, process: ProcessingMethods.adc),
  batteryADC(type: SignalIntTypes.u12l, process: ProcessingMethods.adc),
  ppgADC(type: SignalIntTypes.u12l, process: ProcessingMethods.adc),
  temperature(type: SignalIntTypes.u16b, process: ProcessingMethods.adc),
  pressure(type: SignalIntTypes.u24b, process: ProcessingMethods.adc),
  dataTimestamp(type: SignalIntTypes.u24l),
  fwVersionIDResponse(type: SignalIntTypes.u16l),
  fwMajorResponse(type: SignalIntTypes.u16l),
  fwMinorResponse,
  fwRCResponse,
  devVersionResponse,
  chargeStatusLEDResponse(process: ProcessingMethods.valueMap, valueMap: chargingStatus),
  expBoardIDLengthResponse,
  expBoardIDTypeResponse(process: ProcessingMethods.valueMap, valueMap: expansionBoards),
  expBoardIDRevisionResponse,
  expBoardIDSpeRevisionResponse,
  bluetoothVersionResponse(process: ProcessingMethods.ascii),
  statusCodeResponse(process: ProcessingMethods.messageCode),
  statusBTStreamResponse(
    type: SignalIntTypes.noByteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 4,
    bitMask: 0x10,
  ),
  statusSDLogResponse(
    type: SignalIntTypes.noByteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 3,
    bitMask: 0x08,
  ),
  statusSensingResponse(
    type: SignalIntTypes.noByteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 1,
    bitMask: 0x02,
  ),
  statusDockedResponse(type: SignalIntTypes.byteShift, process: ProcessingMethods.bitShift, bitShift: 0, bitMask: 0x01),
  directoryStringResponse(process: ProcessingMethods.ascii),
  lsm303AHTRAccelRangeResponse(process: ProcessingMethods.valueMap, valueMap: lsm303AHTRAccelRange),
  samplingRateResponse(type: SignalIntTypes.u16l, process: ProcessingMethods.tickSamplingRate),
  lsm303AHTRMagGainResponse(process: ProcessingMethods.valueMap, valueMap: lsm303AHTRMagGain),
  mpu9X50GyroRangeResponse(process: ProcessingMethods.valueMap, valueMap: mpu9X50GyroRange),
  lsm303AHTRAccelDataRateResponse(process: ProcessingMethods.valueMap, valueMap: lsm303AHTRAccelDataRate),
  analogAccelOffsetX(type: SignalIntTypes.i16b),
  analogAccelOffsetY(type: SignalIntTypes.i16b),
  analogAccelOffsetZ(type: SignalIntTypes.i16b),
  analogAccelSensitivityX(type: SignalIntTypes.i16b),
  analogAccelSensitivityY(type: SignalIntTypes.i16b),
  analogAccelSensitivityZ(type: SignalIntTypes.i16b),
  analogAccelAlignRow1ColA(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  analogAccelAlignRow1ColB(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  analogAccelAlignRow1ColC(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  analogAccelAlignRow2ColA(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  analogAccelAlignRow2ColB(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  analogAccelAlignRow2ColC(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  analogAccelAlignRow3ColA(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  analogAccelAlignRow3ColB(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  analogAccelAlignRow3ColC(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  gyroscopeOffsetX(type: SignalIntTypes.i16b),
  gyroscopeOffsetY(type: SignalIntTypes.i16b),
  gyroscopeOffsetZ(type: SignalIntTypes.i16b),
  gyroscopeSensitivityX(type: SignalIntTypes.i16b, process: ProcessingMethods.mpuGyroSensitivity),
  gyroscopeSensitivityY(type: SignalIntTypes.i16b, process: ProcessingMethods.mpuGyroSensitivity),
  gyroscopeSensitivityZ(type: SignalIntTypes.i16b, process: ProcessingMethods.mpuGyroSensitivity),
  gyroscopeAlignRow1ColA(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  gyroscopeAlignRow1ColB(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  gyroscopeAlignRow1ColC(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  gyroscopeAlignRow2ColA(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  gyroscopeAlignRow2ColB(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  gyroscopeAlignRow2ColC(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  gyroscopeAlignRow3ColA(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  gyroscopeAlignRow3ColB(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  gyroscopeAlignRow3ColC(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  magnetometerOffsetX(type: SignalIntTypes.i16b),
  magnetometerOffsetY(type: SignalIntTypes.i16b),
  magnetometerOffsetZ(type: SignalIntTypes.i16b),
  magnetometerSensitivityX(type: SignalIntTypes.i16b),
  magnetometerSensitivityY(type: SignalIntTypes.i16b),
  magnetometerSensitivityZ(type: SignalIntTypes.i16b),
  magnetometerAlignRow1ColA(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  magnetometerAlignRow1ColB(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  magnetometerAlignRow1ColC(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  magnetometerAlignRow2ColA(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  magnetometerAlignRow2ColB(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  magnetometerAlignRow2ColC(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  magnetometerAlignRow3ColA(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  magnetometerAlignRow3ColB(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  magnetometerAlignRow3ColC(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  wrAccelOffsetX(type: SignalIntTypes.u16b),
  wrAccelOffsetY(type: SignalIntTypes.u16b),
  wrAccelOffsetZ(type: SignalIntTypes.u16b),
  wrAccelSensitivityX(type: SignalIntTypes.u16b),
  wrAccelSensitivityY(type: SignalIntTypes.u16b),
  wrAccelSensitivityZ(type: SignalIntTypes.u16b),
  wrAccelAlignRow1ColA(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  wrAccelAlignRow1ColB(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  wrAccelAlignRow1ColC(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  wrAccelAlignRow2ColA(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  wrAccelAlignRow2ColB(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  wrAccelAlignRow2ColC(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  wrAccelAlignRow3ColA(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  wrAccelAlignRow3ColB(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  wrAccelAlignRow3ColC(type: SignalIntTypes.i8, process: ProcessingMethods.alignMatrix),
  expansionBoardInternalPowerResponse(process: ProcessingMethods.boolean),
  shimmerNameResponse(process: ProcessingMethods.ascii),
  experimentIDResponse(process: ProcessingMethods.ascii),
  shimmerNumberResponse,
  configTimestampResponse(process: ProcessingMethods.ascii),
  configLSM303AccelSamplingRate(
    type: SignalIntTypes.noByteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 4,
    bitMask: 0xF0,
    valueMap: lsm303AHTRAccelDataRate,
  ),
  configLSM303AccelRange(
    type: SignalIntTypes.noByteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 2,
    bitMask: 0x0C,
    valueMap: lsm303AHTRAccelRange,
  ),
  configLSM303AccelLowPower(
    type: SignalIntTypes.noByteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 1,
    bitMask: 0x02,
  ),
  configLSM303AccelHighRes(
    type: SignalIntTypes.byteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 0,
    bitMask: 0x01,
  ),
  configMPU9X50SamplingRate(process: ProcessingMethods.mpuGyroDataRate),
  configLSM303MagGain(
    type: SignalIntTypes.noByteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 5,
    bitMask: 0xE0,
    valueMap: lsm303AHTRMagGain,
  ),
  configLSM303MagSamplingRate(
    type: SignalIntTypes.noByteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 2,
    bitMask: 0x1C,
    valueMap: lsm303AHTRMagDataRate,
  ),
  configMPU9X50GyroRange(
    type: SignalIntTypes.byteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 0,
    bitMask: 0x03,
    valueMap: mpu9X50GyroRange,
  ),
  configMPU9X50AccelRange(
    type: SignalIntTypes.noByteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 6,
    bitMask: 0xC0,
    valueMap: mpu9X50AccelRange,
  ),
  configBMPX80PressResolution(
    type: SignalIntTypes.noByteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 4,
    bitMask: 0x30,
    valueMap: bmpX80PressResolution,
  ),
  configGSRRange(
    type: SignalIntTypes.noByteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 1,
    bitMask: 0x0E,
    valueMap: gsrResistanceRange,
  ),
  configExpansionBoardInternalPower(
    type: SignalIntTypes.byteShift,
    process: ProcessingMethods.bitShift,
    bitShift: 0,
    bitMask: 0x01,
  ),
  dataSignalsOrderResponse(process: ProcessingMethods.signalOrder),
  bluetoothBaudRateResponse(process: ProcessingMethods.valueMap, valueMap: btBaudRate),
  bmp280CalibrationT1(type: SignalIntTypes.u16l),
  bmp280CalibrationT2(type: SignalIntTypes.i16l),
  bmp280CalibrationT3(type: SignalIntTypes.i16l),
  bmp280CalibrationP1(type: SignalIntTypes.u16l),
  bmp280CalibrationP2(type: SignalIntTypes.i16l),
  bmp280CalibrationP3(type: SignalIntTypes.i16l),
  bmp280CalibrationP4(type: SignalIntTypes.i16l),
  bmp280CalibrationP5(type: SignalIntTypes.i16l),
  bmp280CalibrationP6(type: SignalIntTypes.i16l),
  bmp280CalibrationP7(type: SignalIntTypes.i16l),
  bmp280CalibrationP8(type: SignalIntTypes.i16l),
  bmp280CalibrationP9(type: SignalIntTypes.i16l),
  batteryVoltageResponse(type: SignalIntTypes.u16l, process: ProcessingMethods.batteryVoltage);

  final SignalIntTypes type;
  final ProcessingMethods process;
  final Map<int, dynamic>? valueMap;
  final int? bitShift;
  final int? bitMask;

  const Signals({
    this.type = SignalIntTypes.u8,
    this.process = ProcessingMethods.int,
    this.valueMap,
    this.bitShift,
    this.bitMask,
  });

  @override
  String toString() => name;
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
  pressureTemp(2, [Signals.temperature, Signals.pressure]);

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

enum ClockMetadata {
  shimmer3(32768, 16777215);

  final int dataMaxRawValue; // max value of u16, u24, etc
  final int clockFreq; // in Hz
  const ClockMetadata(this.clockFreq, this.dataMaxRawValue);
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

double tickSamplingRate(int delayTicks) => 0x8000 / delayTicks;

// Units: Ohms, Default: 4 - Auto
const Map<int, int> gsrRangeResistor = {0: 40200, 1: 287000, 2: 1000000, 3: 3300000};

// Units: Ohms, no default value (sensor is set on auto range by default)
const Map<int, ({double min, double max})> gsrResistanceRange = {
  0: (min: 8000, max: 63000),
  1: (min: 63000, max: 220000),
  2: (min: 220000, max: 680000),
  3: (min: 680000, max: 4700000),
  4: (min: 8000, max: 4700000), // auto range: setting at full range
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

// Units: g, Default: 0 - ±2.0g . Got from MPU9250 manual
const Map<int, double> mpu9X50AccelRange = {0: 2.0, 1: 4.0, 2: 8.0, 3: 16.0};

// Default: 0 - Low pressure resolution
const Map<int, String> bmpX80PressResolution = {0: "Low", 1: "Standard", 2: "High", 3: "Very High"};

// Units: Hz (with decimals for compatibility purposes with LSM303DLHC version)
// Default: 3 - 100.0Hz
const Map<int, double> lsm303AHTRMagDataRate = {0: 10.0, 1: 20.0, 2: 50.0, 3: 100.0};

// Units: Ga
const Map<int, double> lsm303AHTRMagRange = {0: 49.152};

// Units: none
const Map<int, double> lsm303AHTRMagGain = {0: 0, 1: 1.3, 2: 1.9, 3: 2.5, 4: 4.0, 5: 4.7, 6: 5.6, 7: 8.1};

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
  0x80: "Charging", // Original says "Conditioning" I guess they meant "Charging"?
  0xC0: "Bad Battery",
};

const Map<int, String> expansionBoards = {
  0x08: "Expansion Bridge Amplifier Plus",
  0x0E: "Expansion GSR Plus",
  0x1F: "Shimmer3",
  0x24: "Expansion Proto3 Mini",
  0x25: "Expansion EXG",
  0x26: "Expansion Proto3 Deluxe",
  0x2C: "Expansion Board HighG Accel",
  0x2E: "Expansion Board GPS",
  0x2F: "Expansion Board EXG Unified",
  0x30: "Expansion Board GSR Unified",
  0x31: "Expansion Board Bridge Amplifier Unified",
  0x3B: "Shimmer3 EXG Extended",
};

const Map<int, Signals> signalsIDDictionary = {
  0x00: Signals.lowNoiseAccelX,
  0x01: Signals.lowNoiseAccelY,
  0x02: Signals.lowNoiseAccelZ,
  0x04: Signals.wideRangeAccelX,
  0x05: Signals.wideRangeAccelY,
  0x06: Signals.wideRangeAccelZ,
  0x0A: Signals.gyroscopeX,
  0x0B: Signals.gyroscopeY,
  0x0C: Signals.gyroscopeZ,
  0x07: Signals.magnetometerX,
  0x08: Signals.magnetometerY,
  0x09: Signals.magnetometerZ,
  0x1C: Signals.gsrADC,
  0x03: Signals.batteryADC,
  0x12: Signals.ppgADC,
  0x1a: Signals.pressure,
  0x1b: Signals.temperature,
};
