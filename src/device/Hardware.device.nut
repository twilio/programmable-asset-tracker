// TODO: Comment
class PowerSafeI2C {
    _i2c = null;
    _clockSpeed = null;
    _enabled = false;
    _disableTimer = null;

    // TODO: Comment
    constructor(i2c) {
        _i2c = i2c;
    }

    // TODO: Comment
    function configure(clockSpeed) {
        _clockSpeed = clockSpeed;
        _enabled = true;
    }

    // TODO: Comment
    function disable() {
        _i2c.disable();
        _enabled = false;
    }

    // TODO: Comment
    function read(deviceAddress, registerAddress, numberOfBytes) {
        _beforeUse();
        // If the bus is not enabled/configured, this will return null and set the read error code to -13
        return _i2c.read(deviceAddress, registerAddress, numberOfBytes);
    }

    // TODO: Comment
    function readerror() {
        return _i2c.readerror();
    }

    // TODO: Comment
    function write(deviceAddress, registerPlusData) {
        _beforeUse();
        // If the bus is not enabled/configured, this will return -13
        return _i2c.write(deviceAddress, registerPlusData);
    }

    // TODO: Comment
    function _beforeUse() {
        const HW_PSI2C_DISABLE_DELAY = 5;

        // Don't configure i2c bus if the configure() method hasn't been called before
        _enabled && _i2c.configure(_clockSpeed);

        _disableTimer && imp.cancelwakeup(_disableTimer);
        _disableTimer = imp.wakeup(HW_PSI2C_DISABLE_DELAY, (@() _i2c.disable()).bindenv(this));
    }
}

// I2C bus used by:
// - Battery fuel gauge
// - Temperature-humidity sensor
// - Accelerometer
HW_SHARED_I2C <- PowerSafeI2C(hardware.i2cLM);

// Accelerometer's interrupt pin
HW_ACCEL_INT_PIN <- hardware.pinW;

// UART port used for the u-blox module
HW_UBLOX_UART <- hardware.uartPQRS;

// UART port used for logging (if enabled)
HW_LOGGING_UART <- hardware.uartYABCD;

// ESP32 UART port
HW_ESP_UART <- hardware.uartXEFGH;

// ESP32 power enable pin
HW_ESP_POWER_EN_PIN <- hardware.pinXU;

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