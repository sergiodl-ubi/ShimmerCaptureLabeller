# Shimmer Capture Labeller

A Flutter application for real-time Physiological and IMU data capture from a **Shimmer3 GSR+** wearable over Bluetooth Classic.

Data acquisition from a Shimmer3 GSR+ device includes electrodermal activity (EDA/GSR), photoplethysmography (PPG), IMU data, atmospheric pressure, and temperature. The long-term goal is to organize these signals into fixed-duration time windows and use machine learning to attempt real-time recognition of mental or emotional states.

**Status: early development, with an unfinished parsing refactor.** This repository contains an early Bluetooth capture prototype and sensor-processing code. Data preprocessing for/and inference have not been implemented yet.

## Current capabilities

The application and device communication layer contain:

- Bluetooth adapter status and a enabling control.
- Device discovery and selection of paired devices.
- Connection and disconnection handling for a selected device.
- Commands to enable sensors, power the expansion board, and configure the sampling rate (Default: 100Hz).
- Streaming control
  - Start and stop
  - Command flow control through mutex
  - Command ACK (Timeout: 10s)
- A received-data view showing host receipt timestamps and raw byte buffers.

Data organization follows Shimmer's documentation and example codes for packet-length checks, byte-order definitions, IMU calibration matrices, and conversion routines for GSR, PPG, battery voltage, and BMP280 pressure/temperature. These routines are work in progress and are **not connected to the live receive path**: incoming Bluetooth buffers are emitted as `Shimmer3Event` objects rather than decoded sensor measurements.

### Sensor coverage

| Signal               | Intended use            | Current implementation                        |
| -------------------- | ----------------------- | --------------------------------------------- |
| EDA / GSR            | Skin conductance        | Selectible at capture screen; conversion code needs validation.  |
| PPG                  | Heart wave analysis     | Selectible at capture screen; ADC-to-voltage conversion code implemented. |
| Accelerometer        | 3-axis acceleration     | Selectible at capture screen; low-noise and wide-range definitions and calibration implemented. |
| Gyroscope            | 3-axis angular velocity | Should be enabled along Accelerometer; under refactoring. |
| Atmospheric pressure | Environ. pressure       | BMP280 compensation implemented; not enabled at capture screen. Parsing and compensation need review. |
| Temperature          | Environ. temperature    | Defined alongside pressure; not enabled at capture screen. Parsing and compensation need review. |

## Related projects

Bluetooth pairing, connection tests and data packets can be reproduced in a controlled environment via a Raspberry Pi Zero W and the adjacently developed [BluetoothSerialTest](https://github.com/ubi-naist/BluetoothSerialTest) script.

## Getting started

### Prerequisites

- Flutter with a bundled Dart SDK satisfying `^3.6.2`.
- A physical Android device with Bluetooth Classic for data capture.
- A Shimmer3 GSR+ configured for Bluetooth streaming, with the sensors/accessories needed for the signals you want to acquire.
  - Controlled testing can be done through the [BluetoothSerialTest](#related-projects) related project.

As per the time of development, iOS (Apple's iPhone) are not reliable compatible with Bluetooth Classic, so no further iOS compatibility development is planned or expected.

### Capture workflow

The current UI is designed for this sequence:

1. Pair the Shimmer with the Android device through Android's Bluetooth settings. The app filters discovered devices to show only bonded devices.
2. Open the app and enable Bluetooth if needed. Allow Bluetooth permissions when requested.
  - `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT` are declared in the Android manifest.
3. Tap **Start device scan**, then select the paired Shimmer. Opening its device screen attempts a connection.
4. Tap **Start Capture** to configure the selected sensors, enable expansion-board power, set the nominal sampling rate, and request streaming.
5. Inspect incoming timestamped byte buffers under **Received data**.
6. Tap **Stop Capture** to request that streaming stop. Leaving the device screen disposes the connection.

The capture screen currently selects the low-noise accelerometer, gyroscope, GSR, and PPG. There is no sensor-selection or sampling-rate UI; these settings are in [lib/device_screen.dart](lib/device_screen.dart) and `Shimmer3.initialize()` in [lib/src/shimmer3.dart](lib/src/shimmer3.dart).

## Project structure

```text
shimmer_capture_labeller/
├── android/                         Android host application and permissions
├── ios/
├── lib/
│   ├── main.dart                    App entry point and Bluetooth device selection
│   ├── device_screen.dart           Connection, capture controls, raw event display
│   ├── src/
│   │   ├── shimmer3.dart            Communication, frame models, sensor conversions
│   │   └── shimmer3_definitions.dart Protocol codes, sensors, signals, calibration data
│   └── tools/
│       ├── globals.dart             Shared device instance and debug configuration
│       └── logging.dart             Context-prefixed debug logging
├── test/widget_test.dart            Original Flutter counter-app test (marked for deletion)
└── pubspec.yaml                     Package metadata and dependencies
```

Dependencies:

- `flutter_blue_classic` for Bluetooth Classic communication.
- `mutex` for commands serialization and flow control.
- `vector_math` for calibration vectors and matrices manipulation.

## Known limitations and unfinished work

- **Compilation:** `device_screen.dart` references the removed `Sensors.mpuGyro` member. `SensorData` calls `getIntFromDataBlob()` on `Signals` enum values, while the method is defined on the separate `Signal` class. Non-nullable return methods such as `getDeviceConfiguration()` and `Signal.getStringFrom()` also have empty bodies.
- **Stream decoding:** the receive callback forwards Bluetooth buffers directly. It does not yet assemble complete protocol frames across buffers, split combined frames, or route decoded data and response frames into the UI.
- **Response handling:** `ResponseFrame` payload parsing and device-configuration retrieval are unfinished. Acknowledgement detection currently expects an incoming buffer containing only the acknowledgement byte.
- **Sensor processing:** signal names and conversion lookups need reconciliation after the refactor. The pressure/temperature sensor definition repeats the pressure signal, and three-byte signal types currently use four-byte reads. Calibration formulas, units, packet layouts, and device-specific coefficients still need verification.
- **Timekeeping:** displayed timestamps represent host receipt time. Device clock setup is a TODO, and device timestamp decoding, synchronization, and rollover handling are not established.
- **Recording and labelling:** events are held in memory and displayed as text. There is no persistent recording, file export, session management, or annotation workflow. The received-event list grows throughout capture.
- **Validation:** the only checked-in Flutter test is the original counter-app smoke test, which no longer matches the UI. There are no dedicated protocol, calibration, or hardware integration tests.

## Roadmap

1. Complete the signal-parsing refactor.
2. Assemble and decode live protocol frames, finish response handling, and retrieve device configuration and calibration data.
3. Validate capture, timestamps, units, and calibration for all six target signal types on a physical Shimmer3 GSR+; expose pressure and temperature in the capture configuration.
4. Add persistent session recording, export, and a data-labelling workflow.
5. Organize synchronized signals into fixed-duration windows suitable for analysis.
6. Develop and evaluate preprocessing, feature extraction, and machine learning models for the target mental or emotional states.
7. Integrate and evaluate real-time inference in the Android application.
8. Expose a local in-device REST API to expose inference output to other applications.
