import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'package:shimmer_capture_labeller/src/shimmer3_definitions.dart';
import 'package:vector_math/vector_math.dart';
import 'tools/logging.dart';
import 'tools/globals.dart' as globals;
import 'src/shimmer3.dart';

DebugPrintCallback debugPrint = customDebugPrint("DeviceScreen", true);

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key, required this.device});

  final BluetoothDevice device;

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  StreamSubscription? _readSubscription;
  final List<DataFrame> _receivedEvents = [];
  bool successfulSetup = false;
  int shimmerConfigurationTimestamp = 0;
  (Vector3, Matrix3, Matrix3)? analogAccelCalibrationData;
  (Vector3, Matrix3, Matrix3)? gyroscopeCalibrationData;
  (Vector3, Matrix3, Matrix3)? magnetometerCalibrationData;
  (Vector3, Matrix3, Matrix3)? wrAccelCalibrationData;
  BMP280CalibrationData? bmp280calibrationData;

  @override
  void initState() {
    super.initState();
    globals.shimmer3 = Shimmer3(widget.device);
    initializeConnection();
  }

  Future<void> initializeConnection() async {
    if (successfulSetup) {
      return;
    }
    if (!mounted) {
      debugPrint("DeviceScreenState not yet mounted");
      return;
    }
    var success = await globals.shimmer3!.connect();
    if (!success) {
      _showSnackBar("Error connecting to ${widget.device.name}");
      return;
    }

    success = await initializeDevice();

    _readSubscription = globals.shimmer3!.stream.listen((event) {
      if (mounted) {
        setState(() => _receivedEvents.add(event));
      }
    });
    setState(() {
      successfulSetup = true;
    });
  }

  Future<bool> initializeDevice() async {
    var enabledSensors = [Sensors.lowNoiseAccel, Sensors.gyroscope, Sensors.gsr, Sensors.ppg];
    var initialized = await globals.shimmer3!.initialize(enabledSensors);
    if (!initialized) {
      _showSnackBar("Error starting capture stream");
    }
    return initialized;
  }

  Future<bool> startStream() async {
    var started = await globals.shimmer3!.startStreaming();
    if (!started) {
      _showSnackBar("Error starting capture stream");
    }
    return started;
  }

  Future<bool> stopStream() async {
    var stopped = await globals.shimmer3!.stopStreaming();
    if (!stopped) {
      _showSnackBar("Error stopping capture stream");
    }
    return stopped;
  }

  @override
  void dispose() {
    _readSubscription?.cancel();
    globals.shimmer3!.disconnect();
    super.dispose();
  }

  void _showSnackBar(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    } else {
      debugPrint("Snackbar for '$text' called while unmounted");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Connection to ${widget.device.address}")),
      body: ListView(
        children: [
          ElevatedButton(
            onPressed: successfulSetup ? () async => await startStream() : null,
            child: Text("Start Capture"),
          ),
          ElevatedButton(
            onPressed:
                successfulSetup
                    ? () async {
                      await stopStream();
                    }
                    : null,
            child: Text("Stop Capture"),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("Received data", style: Theme.of(context).textTheme.titleLarge),
          ),
          for (var event in _receivedEvents) Text(event.toString()),
        ],
      ),
    );
  }
}
