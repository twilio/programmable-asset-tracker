// Accelerometer's I2C bus
HW_SHARED_I2C <- PowerSafeI2C(hardware.i2cLM);

// Accelerometer's interrupt pin
HW_ACCEL_INT_PIN <- hardware.pinW;

// UART port used for the u-blox module
HW_UBLOX_UART <- hardware.uartXEFGH;

// U-blox module power enable pin
HW_UBLOX_POWER_EN_PIN <- hardware.pinG;

// U-blox module backup power enable pin (flip-flop)
HW_UBLOX_BACKUP_PIN <- FlipFlop(hardware.pinYD, hardware.pinYM);

// UART port used for logging (if enabled)
HW_LOGGING_UART <- hardware.uartYJKLM;

// ESP32 UART port
HW_ESP_UART <- hardware.uartABCD;

// ESP32 power enable pin (flip-flop)
HW_ESP_POWER_EN_PIN <- FlipFlop(hardware.pinYD, hardware.pinS);

// Light Dependent Photoresistor pin
HW_LDR_PIN <- hardware.pinV;

// Light Dependent Photoresistor power enable pin
HW_LDR_POWER_EN_PIN <- FlipFlop(hardware.pinYD, hardware.pinXM);

// Battery level measurement pin
HW_BAT_LEVEL_PIN <- hardware.pinXD;

// Battery level measurement power enable pin
HW_BAT_LEVEL_POWER_EN_PIN <- hardware.pinYG;

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

// Allocation for the SPI Flash File System used by Cfg Manager
const HW_CFGM_SFFS_START_ADDR = 0x300000;
const HW_CFGM_SFFS_END_ADDR = 0x340000;

// The range to be erased if ERASE_FLASH build-flag is active and a new deployment is detected
const HW_ERASE_FLASH_START_ADDR = 0x000000;
const HW_ERASE_FLASH_END_ADDR = 0x340000;