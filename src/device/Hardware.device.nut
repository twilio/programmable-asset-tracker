// Temperature-humidity sensor's I2C bus
// NOTE: This I2C bus is used by the accelerometer as well. And it's configured by the accelerometer
HW_TEMPHUM_SENSOR_I2C <- hardware.i2cLM;
// Accelerometer's I2C bus
// NOTE: This I2C bus is used by the temperature-humidity sensor as well. But it's configured by the accelerometer
HW_ACCEL_I2C <- hardware.i2cLM;
// Accelerometer's interrupt pin
HW_ACCEL_INT_PIN <- hardware.pinW;

// SPI Flash allocations

// Allocation for the SPI Flash Logger used by ReplayMessenger
const HW_RM_SFL_START_ADDR = 0x000000;
const HW_RM_SFL_END_ADDR = 0x100000;
