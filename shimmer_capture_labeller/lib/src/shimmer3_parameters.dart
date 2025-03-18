// ########### Sensors Parameters ##########

// Units: Ohms, Default: 4 - Auto
const Map<int, int> gsrRangeResistor = {
  0: 40200,
  1: 287000,
  2: 1000000,
  3: 3300000,
  4: 0, // Auto: automatically changes between resistors according to signal
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
const Map<int, int> mpu9X50GyroRange = {
  0: 250,
  1: 500,
  2: 1000,
  3: 20000,
};

// Default: 0 - Low pressure resolution
const Map<int, String> bmpX80PressResolution = {
  0: "Low",
  1: "Standard",
  2: "High",
  3: "Very High",
};

// Units: Hz (with decimals for compatibility purposes with LSM303DLHC version)
// Default: 3 - 100.0Hz
const Map<int, double> lsm303AHTRMagDataRate = {
  0: 10.0,
  1: 20.0,
  2: 50.0,
  3: 100.0,
};

// Units: Ga
const Map<int, double> lsm303AHTRMagRange = {
  0: 49.152,
};

// Units: g, Default: 0 - ±2.0g
const Map<int, double> lsm303AHTRAccelRange = {
  0: 2.0,
  1: 16.0,
  2: 4.0,
  3: 8.0,
};

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

// ########### Sensors default calibration values ##########

enum BMP280CalibrationValues {
  t1(27504),
  t2(26435),
  t3(-1000),
  p1(36477),
  p2(-10685),
  p3(3024),
  p4(2855),
  p5(140),
  p6(-7),
  p7(15500),
  p8(-14600),
  p9(6000);

  final double value;
  const BMP280CalibrationValues(this.value);
}
