// Temperature-humidity sensor's I2C bus
// NOTE: This I2C bus is used by the accelerometer as well. And it's configured by the accelerometer
HW_TEMPHUM_SENSOR_I2C <- hardware.i2cLM;
// Accelerometer's I2C bus
// NOTE: This I2C bus is used by the temperature-humidity sensor as well. But it's configured by the accelerometer
HW_ACCEL_I2C <- hardware.i2cLM;
// Accelerometer's interrupt pin
HW_ACCEL_INT_PIN <- hardware.pinW;

// UART port used for the u-blox module
// TODO: Choose another uart port
HW_UBLOX_UART <- hardware.uartXEFGH;

// UART port used for logging (if enabled)
HW_LOGGING_UART <- hardware.uartYABCD;

// LED indication: RED pin
HW_LED_RED_PIN <- hardware.pinR;
// LED indication: GREEN pin
HW_LED_GREEN_PIN <- hardware.pinXA;
// LED indication: BLUE pin
HW_LED_BLUE_PIN <- hardware.pinXB;

// SPI Flash allocations

// Allocation for the SPI Flash Logger used by Replay Messenger
const HW_RM_SFL_START_ADDR = 0x000000;
const HW_RM_SFL_END_ADDR = 0x100000;

// Allocation for the SPI Flash File System used by Location Driver
const HW_LD_SFFS_START_ADDR = 0x200000;
const HW_LD_SFFS_END_ADDR = 0x240000;
