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
}

enum Sensors {
  analogAccel(23),
  mpuGyro(22),
  lsmMagnetometer(21),
  gsr(18),
  battery(13),
  lsmAccel(12),
  ppg(8),
  mpuAccel(6),
  mpuMagnetometer(5),
  pressureTemp(2);

  final int bitShift;
  const Sensors(this.bitShift);
}

class Shimmer3Event {
  final DateTime datetime;
  final Uint8List message;

  Shimmer3Event(this.datetime, this.message);
  Shimmer3Event.fromMilliseconds(int timestamp, this.message)
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
  BluetoothConnection? _connection;

  StreamSubscription? _readSubscription;
  List<Shimmer3Event> receivedEvents = <Shimmer3Event>[];
  final ackTimeout = 10;

  Shimmer3(this.device) {
    _blueClassic = FlutterBlueClassic(usesFineLocation: false);
  }

  bool get isConnected => _connection?.isConnected ?? false;

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
    _readSubscription = _connection!.input?.listen((uBuffer) =>
        receivedEvents.add(Shimmer3Event(DateTime.now(), uBuffer)));
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
    var output = String.fromCharCodes(data);
    _connection!.writeString(output);
    return true;
  }

  int flushQueue() {
    var queueLength = receivedEvents.length;
    receivedEvents.clear();
    return queueLength;
  }

  Future<bool> sendCommand(String description, Uint8List payload) async {
    if (!(await sendData(payload))) {
      debugPrint("Failed to $description: data not sent");
      return false;
    }
    if (!(await waitForAck(timeout: ackTimeout))) {
      debugPrint("Failed to $description: ack timeout");
      return false;
    }
    return true;
  }

  Future<bool> waitForAck({timeout = 10}) async {
    var acknowledged = false;
    var expirationTime =
        DateTime.now().millisecondsSinceEpoch + (timeout * 1000);
    while (!acknowledged) {
      if (DateTime.now().millisecondsSinceEpoch > expirationTime) {
        break;
      }
      if (receivedEvents.isEmpty) {
        await Future.delayed(Duration(milliseconds: 50));
        continue;
      }
      for (final (idx, event) in receivedEvents.indexed) {
        if (event.message == Commands.acknowledge.asUint8List()) {
          acknowledged = true;
          receivedEvents.removeAt(idx);
          break;
        }
      }
    }
    return acknowledged;
  }

  Future<bool> initialize(List<Sensors> sensors, {sampleRate = 100}) async {
    return _commMutex.protect<bool>(() async {
      int command, byte0, byte1, byte2;
      flushQueue();

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
      int clockWait = ((1 << 15) / sampleRate).round();
      byte0 = (clockWait & 0x00ff);
      byte1 = (clockWait & 0xff00) >> 8;
      payload = Uint8List.fromList([command, byte0, byte1]);

      if (!(await sendCommand("set up sampling rate", payload))) {
        return false;
      }

      return true;
    });
  }

  Future<bool> startStreaming() async {
    return _commMutex.protect<bool>(() async {
      var payload = Uint8List.fromList([Commands.startStreaming.value]);
      if (!(await sendCommand("starting streaming", payload))) {
        return false;
      }
      return true;
    });
  }

  Future<bool> stopStreaming() async {
    return _commMutex.protect<bool>(() async {
      var payload = Uint8List.fromList([Commands.stopStreaming.value]);
      if (!(await sendCommand("stopping streaming", payload))) {
        return false;
      }
      return true;
    });
  }
}
