import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

class Shimmer3 {
  final BluetoothDevice device;
  late BluetoothConnection connection;
  late FlutterBlueClassic _blueClassic;

  Shimmer3(this.device) {
    _blueClassic = FlutterBlueClassic(usesFineLocation: false);
    _blueClassic.connect(device.address).then((value) => {
          if (value != null)
            {connection = value}
          else
            {throw Exception("Failed to connect to $device")}
        });
  }

  bool sendData(ByteData data) {
    var output = String.fromCharCodes(data.buffer.asUint8List());
    connection.writeString(output);
    return true;
  }
}
