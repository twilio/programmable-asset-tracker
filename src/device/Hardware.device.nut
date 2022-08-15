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

// TODO: Comment
class FlipFlop {
    _clkPin = null;
    _switchPin = null;

    // TODO: Comment
    constructor(clkPin, switchPin) {
        _clkPin = clkPin;
        _switchPin = switchPin;
    }

    // TODO: Comment
    function _get(key) {
        if (!(key in _switchPin)) {
            throw null;
        }

        // We want to clock the flip-flop after every change on the pin. This will trigger clocking even when the pin is being read.
        // But this shouldn't affect anything. Moreover, it's assumed that DIGITAL_OUT pins are read rarely.
        // To "attach" clocking to every pin's function, we return a wrapper-function that calls the requested original pin's
        // function and then clocks the flip-flop. This will make it transparent for the other components/modules.
        // All members of hardware.pin objects are functions. Hence we can always return a function here
        return function(...) {
            // Let's call the requested function with the arguments passed
            vargv.insert(0, _switchPin);
            // Also, we save the value returned by the original pin's function
            local res = _switchPin[key].acall(vargv);

            // Then we clock the flip-flop assuming that the default pin value is LOW (externally pulled-down)
            _clkPin.configure(DIGITAL_OUT, 1);
            _clkPin.disable();

            // Return the value returned by the original pin's function
            return res;
        };
    }
}

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