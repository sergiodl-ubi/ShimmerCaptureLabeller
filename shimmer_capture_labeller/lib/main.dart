import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

import 'package:shimmer_capture_labeller/device_info.dart';
import 'tools/logging.dart';

DebugPrintCallback debugPrint = customDebugPrint("Main", true);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shimmer Capture Labeller',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const StartPage(title: 'Device Selection'),
    );
  }
}

class StartPage extends StatefulWidget {
  const StartPage({super.key, required this.title});

  final String title;

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  final _blueClassic = FlutterBlueClassic(usesFineLocation: false);

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription? _adapterStateSubscription;

  final Set<BluetoothDevice> _scanResults = {};
  StreamSubscription? _scanSubscription;

  bool _isScanning = false;
  int? _connectingToIndex;
  StreamSubscription? _scanningStateSubscription;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    BluetoothAdapterState adapterState = _adapterState;

    try {
      adapterState = await _blueClassic.adapterStateNow;
      _adapterStateSubscription = _blueClassic.adapterState.listen((current) {
        if (mounted) setState(() => _adapterState = current);
      });
      _scanSubscription = _blueClassic.scanResults.listen((device) {
        if (mounted) setState(() => _scanResults.add(device));
      });
      _scanningStateSubscription = _blueClassic.isScanning.listen((isScanning) {
        if (mounted) setState(() => _isScanning = isScanning);
      });
    } catch (e) {
      debugPrint("Failed to initialize Bluetooth library: $e");
    }

    if (!mounted) return;

    debugPrint("Bluetooth library initialized");
    setState(() {
      _adapterState = adapterState;
    });
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanSubscription?.cancel();
    _scanningStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<BluetoothDevice> scanResults = _scanResults.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select device'),
      ),
      body: ListView(
        children: [
          ListTile(
            title: const Text("Bluetooth Adapter state"),
            subtitle: const Text("Tap to enable"),
            trailing: Text(_adapterState.name),
            leading: const Icon(Icons.settings_bluetooth),
            onTap: () => _blueClassic.turnOn(),
          ),
          const Divider(),
          if (scanResults.isEmpty)
            const Center(child: Text("No devices found yet"))
          else
            for (var (index, device) in scanResults.indexed)
              ListTile(
                title: Text("${device.name ?? "???"} (${device.address})"),
                subtitle: Text(
                    "Paired: ${device.bondState.name}, Type: ${device.type.name}"),
                trailing: index == _connectingToIndex
                    ? const CircularProgressIndicator()
                    : Text("${device.rssi} dBm"),
                onTap: () async {
                  BluetoothConnection? connection;
                  setState(() => _connectingToIndex = index);
                  try {
                    connection = await _blueClassic.connect(device.address);
                    if (!this.context.mounted) return;
                    if (connection != null && connection.isConnected) {
                      if (mounted) setState(() => _connectingToIndex = null);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  DeviceInfo(connection: connection!)));
                    }
                  } catch (e) {
                    if (mounted) setState(() => _connectingToIndex = null);
                    debugPrint(
                        "Failed to connect to ${device.name}@${device.address}");
                    connection?.dispose();
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                        const SnackBar(
                            content: Text("Error connecting to device")));
                  }
                },
              )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_isScanning) {
            _blueClassic.stopScan();
          } else {
            _scanResults.clear();
            _blueClassic.startScan();
          }
        },
        label: Text(_isScanning ? "Scanning..." : "Start device scan"),
        icon: Icon(_isScanning ? Icons.bluetooth_searching : Icons.bluetooth),
      ),
    );
  }
}
