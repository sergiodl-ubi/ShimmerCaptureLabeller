import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:mutex/mutex.dart';
import 'tools/logging.dart';

DebugPrintCallback debugPrint = customDebugPrint("Shimmer3", true);
Mutex _commMutex = Mutex();

enum Commands {
  initSensors(0x08),
  setSamplingRate(0x05),
  startStreaming(0x07),
  stopStreaming(0x20),
  enableExpIntPower(0x5e),
  acknowledge(0xFF);

  final int value;
  const Commands(this.value);
  Uint8List asUint8List() => Uint8List.fromList([value]);
  bool sameAsMessage(Uint8List msg) =>
      msg.length == 1 && msg.single.toInt() == value;
}

enum Sensors {
  analogAccel(23, 6, true),
  mpuGyro(22, 6, false),
  lsmMagnetometer(21, 6, false),
  gsr(18, 2, true),
  battery(13, 2, true),
  lsmAccel(12, 6, false),
  ppg(8, 2, true),
  mpuAccel(6, 6, false),
  mpuMagnetometer(5, 6, false),
  pressureTemp(2, 5, false);

  final int bitShift;
  final int packetLength;
  final bool isLittleEndian;
  const Sensors(this.bitShift, this.packetLength, this.isLittleEndian);
  @override
  String toString() => name;
}

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
      if (Commands.acknowledge.sameAsMessage(buffer)) {
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
        if (Commands.acknowledge.sameAsMessage(event.message)) {
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
        configuration += 1 << sensor.bitShift;
      }
      command = Commands.initSensors.value;
      byte0 = (configuration & 0x00ff0000) >> 16;
      byte1 = (configuration & 0x0000ff00) >> 8;
      byte2 = (configuration & 0x000000ff);
      Uint8List payload = Uint8List.fromList([command, byte0, byte1, byte2]);

      if (!(await sendCommand("set up sensors", payload))) {
        return false;
      }

      // Enable expansion board internal power
      command = Commands.enableExpIntPower.value;
      payload = Uint8List.fromList([command, 1]);

      if (!(await sendCommand("enable expansion board power", payload))) {
        return false;
      }

      // Set sampling rate
      command = Commands.setSamplingRate.value;
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
      var payload = Commands.startStreaming.asUint8List();
      if (!(await sendCommand("starting streaming", payload))) {
        return false;
      }
      _streaming = true;
      return true;
    });
  }

  Future<bool> stopStreaming() async {
    return _commMutex.protect<bool>(() async {
      var payload = Commands.stopStreaming.asUint8List();
      if (!(await sendCommand("stopping streaming", payload))) {
        return false;
      }
      _streaming = false;
      return true;
    });
  }
}
