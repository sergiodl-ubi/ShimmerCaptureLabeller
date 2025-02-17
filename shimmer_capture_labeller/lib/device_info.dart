import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'tools/logging.dart';

DebugPrintCallback debugPrint = customDebugPrint("DeviceInfo", true);

class DeviceInfo extends StatefulWidget {
  const DeviceInfo({super.key, required this.connection});

  final BluetoothConnection connection;

  @override
  State<DeviceInfo> createState() => _DeviceInfoState();
}

class _DeviceInfoState extends State<DeviceInfo> {
  StreamSubscription? _readSubscription;
  final List<String> _receivedInput = [];

  @override
  void initState() {
    _readSubscription = widget.connection.input?.listen((event) {
      if (mounted) {
        setState(() => _receivedInput.add(utf8.decode(event)));
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    widget.connection.dispose();
    _readSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Connection to ${widget.connection.address}"),
      ),
      body: ListView(
        children: [
          ElevatedButton(
              onPressed: () {
                try {
                  widget.connection.writeString("hello world");
                } catch (e) {
                  debugPrint("Failed to write to device: $e");
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
                      content: Text(
                          "Error sending to device. Device is ${widget.connection.isConnected ? "connected" : "not connected"}")));
                }
              },
              child: const Text("Send hello world to remote device")),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("Received data",
                style: Theme.of(context).textTheme.titleLarge),
          ),
          for (String input in _receivedInput) Text(input),
        ],
      ),
    );
  }
}
