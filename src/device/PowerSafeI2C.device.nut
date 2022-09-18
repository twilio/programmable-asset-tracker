@set CLASS_NAME = "PowerSafeI2C" // Class name for logging

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

@set CLASS_NAME = null // Reset the variable
