// MIT License

// Copyright (C) 2022, Twilio, Inc. <help@twilio.com>

// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do
// so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@set CLASS_NAME = "PowerSafeI2C" // Class name for logging

// Power Safe I2C class.
// Proxies a hardware.i2cXX object but keeps it disabled most of the time
class PowerSafeI2C {
    _i2c = null;
    _clockSpeed = null;
    _enabled = false;
    _disableTimer = null;

    /**
     * Constructor for PowerSafeI2C class
     *
     * @param {object} i2c - The I2C object to be proxied by this class
     */
    constructor(i2c) {
        _i2c = i2c;
    }

    /**
     * Configures the I2C clock speed and enables the port.
     * Actually, it doesn't enable the port itself but only sets an
     * internal flag allowing the port to be enabled once needed
     *
     * @param {integer} clockSpeed - The preferred I2C clock speed
     */
    function configure(clockSpeed) {
        _clockSpeed = clockSpeed;
        _enabled = true;
    }

    /**
     * Disables the I2C bus
     */
    function disable() {
        _i2c.disable();
        _enabled = false;
    }

    /**
     * Initiates an I2C read from a specific register within a specific device
     *
     * @param {integer} deviceAddress - The 8-bit I2C base address
     * @param {integer} registerAddress - The I2C sub-address, or "" for none
     * @param {integer} numberOfBytes - The number of bytes to read from the bus
     *
     * @return {string | null} the characters read from the I2C bus, or null on error
     */
    function read(deviceAddress, registerAddress, numberOfBytes) {
        _beforeUse();
        // If the bus is not enabled/configured, this will return null and set the read error code to -13
        return _i2c.read(deviceAddress, registerAddress, numberOfBytes);
    }

    /**
     * Returns the error code generated by the last I2C read
     *
     * @return {integer} an I2C error code, or 0 (no error)
     */
    function readerror() {
        return _i2c.readerror();
    }

    /**
     * Initiates an I2C write to the device at the specified address
     *
     * @param {integer} deviceAddress - The 8-bit I2C base address
     * @param {string} registerPlusData - The I2C sub-address and data, or "" for none
     *
     * @return {integer} 0 for success, or an I2C Error Code
     */
    function write(deviceAddress, registerPlusData) {
        _beforeUse();
        // If the bus is not enabled/configured, this will return -13
        return _i2c.write(deviceAddress, registerPlusData);
    }

    function _beforeUse() {
        const HW_PSI2C_DISABLE_DELAY = 5;

        // Don't configure i2c bus if the configure() method hasn't been called before
        _enabled && _i2c.configure(_clockSpeed);

        _disableTimer && imp.cancelwakeup(_disableTimer);
        _disableTimer = imp.wakeup(HW_PSI2C_DISABLE_DELAY, (@() _i2c.disable()).bindenv(this));
    }
}

@set CLASS_NAME = null // Reset the variable
