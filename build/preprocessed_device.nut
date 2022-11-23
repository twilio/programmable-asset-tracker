
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

#require "Serializer.class.nut:1.0.0"
#require "JSONParser.class.nut:1.0.1"
#require "JSONEncoder.class.nut:2.0.0"
#require "Promise.lib.nut:4.0.0"
#require "SPIFlashLogger.device.lib.nut:2.2.0"
#require "SPIFlashFileSystem.device.lib.nut:3.0.1"
#require "ConnectionManager.lib.nut:3.1.1"
#require "Messenger.lib.nut:0.2.0"
#require "ReplayMessenger.device.lib.nut:0.2.0"
#require "utilities.lib.nut:3.0.1"
#require "LIS3DH.device.lib.nut:3.0.0"
#require "UBloxM8N.device.lib.nut:1.0.1"
#require "UbxMsgParser.lib.nut:2.0.1"
#require "UBloxAssistNow.device.lib.nut:0.1.0"
#require "BG96_Modem.device.lib.nut:0.0.4"

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

// Application Version
const APP_VERSION = "3.1.2";
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

// Constants common for the imp-agent and the imp-device

// ReplayMessenger message names
enum APP_RM_MSG_NAME {
    DATA = "data",
    GNSS_ASSIST = "gnssAssist",
    LOCATION_CELL_WIFI = "locationCellAndWiFi",
    CFG = "cfg"
}

// Init latitude value (North Pole)
const INIT_LATITUDE = 90.0;

// Init longitude value (Greenwich)
const INIT_LONGITUDE = 0.0;
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

// Logger for "DEBUG", "INFO" and "ERROR" information.
// Prints out information to the standard impcentral log ("server.log").
// The supported data types: string, table. Other types may be printed out incorrectly.
// The logger should be used like the following: `::info("log text", "optional log source")`

// If the log storage is configured, logs that cannot be printed while imp-device is offline
// are stored in RAM or Flash and are printed out later, when imp-device becomes back online.

// Log levels
enum LGR_LOG_LEVEL {
    ERROR, // enables output from the ::error() method only - the "lowest" log level
    INFO,  // enables output from the ::error() and ::info() methods
    DEBUG  // enables output from from all methods - ::error(), ::info() and ::debug() - the "highest" log level
}

Logger <- {
    VERSION = "0.2.0",

    // Current Log level to display
    _logLevel = LGR_LOG_LEVEL.INFO,

    // Log level to save in the log storage
    _logStgLvl = LGR_LOG_LEVEL.INFO,

    // The instance of the logger.IStorage.
    // Each item is table:
    //      "multiRow" : {boolean} - If true the multi-line mode of log output is used, one-line mode otherwise
    //      "prefix" : {string} - String with a prefix part of the log
    //      "log" : {string} - String with the main part of the log
    _logStg = null,

    // If true the log storage is enabled, otherwise the log storage is disabled
    _logStgEnabled = false,

    // Output stream for logging using server.log()
    // Implements the Logger.IOutputStream interface
    _outStream = {
        write = function(msg) {
            return server.log(msg);
        }
    },

    /**
     * Logs DEBUG information
     *
     * @param {any type} obj - Data to log
     * @param {string} [src] - Name of the data source. Optional.
     * @param {boolean} [multiRow] - If true, then each LINE FEED symbol in the data log
     *          prints the following data on a new line. Applicable to string data logs.
     *          Optional. Default: false
     */
    function debug(obj, src = null, multiRow = false) {
        local saveLog = _logStgLvl >= LGR_LOG_LEVEL.DEBUG && _logStgEnabled && null != _logStg;
        (_logLevel >= LGR_LOG_LEVEL.DEBUG) && _log("DEBUG", obj, src, multiRow, saveLog);
    },

    /**
     * Logs INFO information
     *
     * @param {any type} obj - Data to log
     * @param {string} [src] - Name of the data source. Optional.
     * @param {boolean} [multiRow] - If true, then each LINE FEED symbol in the data log
     *          prints the following data on a new line. Applicable to string data logs.
     *          Optional. Default: false
     */
    function info(obj, src = null, multiRow = false) {
        local saveLog = _logStgLvl >= LGR_LOG_LEVEL.INFO && _logStgEnabled && null != _logStg;
        (_logLevel >= LGR_LOG_LEVEL.INFO) && _log("INFO", obj, src, multiRow, saveLog);
    },

    /**
     * Logs ERROR information
     *
     * @param {any type} obj - Data to log
     * @param {string} [src] - Name of the data source. Optional.
     * @param {boolean} [multiRow] - If true, then each LINE FEED symbol in the data log
     *          prints the following data on a new line. Applicable to string data logs.
     *          Optional. Default: false
     */
    function error(obj, src = null, multiRow = false) {
        local saveLog = _logStgLvl >= LGR_LOG_LEVEL.ERROR && _logStgEnabled && null != _logStg;
        (_logLevel >= LGR_LOG_LEVEL.ERROR) && _log("ERROR", obj, src, multiRow, saveLog);
    },

    /**
     * Sets Log output to the specified level.
     * If not specified, resets to the default.
     *
     * @param {enum} [level] - Log level (LGR_LOG_LEVEL), optional
     *          Default: LGR_LOG_LEVEL.INFO
     */
    function setLogLevel(level = LGR_LOG_LEVEL.INFO) {
        _logLevel = level;
    },

    /**
     * Sets Log output to the level specified by string.
     * Supported strings: "error", "info", "debug" - case insensitive.
     * If not specified or an unsupported string, resets to the default.
     *
     * @param {string} [level] - Log level case insensitive string ["error", "info", "debug"]
     *          By default and in case of an unsupported string: LGR_LOG_LEVEL.INFO
     */
    function setLogLevelStr(level = "info") {
        (null != level) && (_logLevel = _logLevelStrToEnum(level));
    },

    /**
     * Get current log level in string format.
     * Supported strings: "error", "info", "debug" - case insensitive.
     *
     * @return {string} - Log level string ["error", "info", "debug"]
     */
    function getLogLevelStr() {
        return _logLevelEnumToStr(_logLevel);
    },

    /**
     * Sets output stream
     *
     * @param {Logger.IOutputStream} iStream - instance of an object that implements the Logger.IOutputStreem interface
     */
    function setOutputStream(iStream) {
        if (Logger.IOutputStream == iStream.getclass().getbase()) {
            _outStream = iStream;
        } else {
            throw "The iStream object must implement the Logger.IOutputStream interface"
        }
    }

    /**
     * Sets a storage
     *
     * @param {Logger.IStorage} iStorage - The instance of an object that implements the Logger.IStorage interface
     */
    function setStorage(iStorage) {
        _logStg = null;
        server.error("Logger storage disabled. Set LOGGER_STORAGE_ENABLE parameter to true.");
    },

    /**
     * Gets a storage
     *
     * @return{Logger.IStorage | null} - Instance of the Logger.IStorage object or null.
     */
    function getStorage() {
        server.error("Logger storage disabled. Set LOGGER_STORAGE_ENABLE parameter to true.");
        return null;
    }

    /**
     * Enables/configures or disables log storage
     *
     * @param {boolean} enabled - If true the log storage is enabled, otherwise the log storage is disabled
     * @param {string} [level] - Log level to save in the storage: "error", "info", "debug". Optional. Default: "info".
     *                               If the specified level is "higher" than the current log level to display,
     *                               then the level to save is set equal to the current level to display.
     * @param {integer} [num] - Maximum number of logs to store. Optional. Default: 0.
     */
    function setLogStorageCfg(enabled, level = "info") {
        _logStgLvl     = LGR_LOG_LEVEL.INFO;
        _logStgEnabled = false;
        server.error("Logger storage disabled. Set LOGGER_STORAGE_ENABLE parameter to true.");
    },

    /**
     * Prints out logs that are stored in the log storage to the impcentral log.
     *
     * @param {integer} [num] - Maximum number of logs to print. If 0 - try to print out all stored logs.
     *                              Optional. Default: 0.
     *
     * @return {boolean} - True if successful, False otherwise.
     */

    function printStoredLogs(num = 0) {
        server.error("Logger storage disabled. Set LOGGER_STORAGE_ENABLE parameter to \"true\".");
    },

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Forms and outputs a log message
     *
     * @param {string} levelName - Level name to log
     * @param {any type} obj - Data to log
     * @param {string} src - Name of the data source.
     * @param {boolean} multiRow - If true, then each LINE FEED symbol in the data log
     *          prints the following data on a new line. Applicable to string data logs.
     * @param {boolean} saveLog - If true, then if there is no connection,
     *          the log will be saved in the log storage for sending when the connection is restored.
     */
    function _log(levelName, obj, src, multiRow, saveLog) {
        local prefix = "[" + levelName + "]";
        src && (prefix += "[" + src + "]");
        prefix += " ";

        local objType = typeof(obj);
        local srvErr;
        local lg = "";

        if (objType == "table") {
            lg       = _tableToStr(obj);
            multiRow = true;
        } else {
            try {
                lg = obj.tostring();
            } catch(exp) {
                server.error("Exception during output log message: " + exp);
                return;
            }
        }

        if (multiRow) {
            srvErr = _logMR(prefix, lg);
        } else {
            srvErr = _outStream.write(prefix + lg);
        }

    },

    /**
     * Outputs a log message in multiRow mode
     *
     * @param {string} prefix - Prefix part of the log.
     * @param {string} str - Main part of the log.
     *
     * @return {integer} - 0 on success, or a _outStream.write() "Send Error Code" if it fails to output at least one line.
     */
    function _logMR(prefix, str) {
        local srvErr;
        local rows = split(str, "\n");

        srvErr = _outStream.write(prefix + rows[0]);
        if (srvErr) {
            return srvErr;
        }

        local tab = blob(prefix.len());
        for (local i = 0; i < prefix.len(); i++) {
            tab[i] = ' ';
        }
        tab = tab.tostring();

        for (local rowIdx = 1; rowIdx < rows.len(); rowIdx++) {
            srvErr = _outStream.write(tab + rows[rowIdx]);
            if (srvErr) {
                return srvErr;
            }
        }

        return srvErr;
    },

    /**
    * Converts table to string suitable for output in multiRow mode
    *
    * @param {table} tbl - The table
    * @param {integer} [level] - Table nesting level. For nested tables. Optional. Default: 0
    *
    * @return {string} - log suitable for output in multiRow mode.
    */
    function _tableToStr(tbl, level = 0) {
        local ret = "";
        local tab = "";

        for (local i = 0; i < level; i++) tab += "    ";

        ret += "{\n";
        local innerTab = tab + "    ";

        foreach (k, v in tbl) {
            if (typeof(v) == "table") {
                ret += innerTab + k + " : ";
                ret += _tableToStr(v, level + 1) + "\n";
            } else if (typeof(v) == "array") {
                local str = "[";

                foreach (v1 in v) {
                    str += v1 + ", ";
                }

                ret += innerTab + k + " : " + str + "],\n";
            } else if (v == null) {
                ret += innerTab + k + " : null,\n";
            } else {
                ret += format(innerTab + k + " : %s,", v.tostring()) + "\n";
            }
        }

        ret += tab + "}";
        return ret;
    },


    /**
     * Converts log level specified by string to log level enum for Logger .
     * Supported strings: "error", "info", "debug" - case insensitive.
     * If not specified or an unsupported string, resets to the default.
     *
     * @param {string} [level] - Log level case insensitive string ["error", "info", "debug"]
     *          By default and in case of an unsupported string: LGR_LOG_LEVEL.INFO
     *
     * @return {enum} - Log level enum value for Logger
     */
    function _logLevelStrToEnum(levelStr) {
        local lgrLvl;
        switch (levelStr.tolower()) {
            case "error":
                lgrLvl = LGR_LOG_LEVEL.ERROR;
                break;
            case "info":
                lgrLvl = LGR_LOG_LEVEL.INFO;
                break;
            case "debug":
                lgrLvl = LGR_LOG_LEVEL.DEBUG;
                break;
            default:
                lgrLvl = LGR_LOG_LEVEL.INFO;
                break;
        }
        return lgrLvl;
    },

    /**
     * Converts log level to string.
     * Supported strings: "error", "info", "debug", "unknown".
     *
     * @param {enum} [level] - Log level enum value
     *
     * @return {string} - Log level case insensitive string ["error", "info", "debug", "unknown"]
     */
    function _logLevelEnumToStr(level) {
        local lgrLvlStr;
        switch (level) {
            case LGR_LOG_LEVEL.ERROR:
                lgrLvlStr = "error";
                break;
            case LGR_LOG_LEVEL.INFO:
                lgrLvlStr = "info";
                break;
            case LGR_LOG_LEVEL.DEBUG:
                lgrLvlStr = "debug";
                break;
            default:
                lgrLvlStr = "unknown";
                break;
        }
        return lgrLvlStr;
    }
}

// Setup global variables:
// the logger should be used like the following: `::info("log text", "optional log source")`
::debug <- Logger.debug.bindenv(Logger);
::info  <- Logger.info.bindenv(Logger);
::error <- Logger.error.bindenv(Logger);

Logger.setLogLevelStr("INFO");


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

/**
 * Logger output stream interface
 */
Logger.IOutputStream <- class {
    //  ------ PUBLIC FUNCTIONS TO OVERRIDE  ------- //
    function write(data) { throw "The Write method must be implemented in an inherited class" }
    function flush() { throw "The Flush method must be implemented in an inherited class" }
    function close() { throw "The Close method must be implemented in an inherited class" }
};


/**
 * UART Output Stream.
 * Used for logging to UART and standard imp log in parallel
 */
class UartOutputStream extends Logger.IOutputStream {
    _uart = null;

    /**
     * Constructor for UART Output Stream
     *
     * @param {object} uart - The UART port object to be used for logging
     * @param {integer} [baudRate = 115200] - UART baud rate
     */
    constructor(uart, baudRate = 115200) {
        _uart = uart;
        _uart.configure(baudRate, 8, PARITY_NONE, 1, NO_CTSRTS | NO_RX);
    }

    /**
     * Write data to the output stream
     *
     * @param {any type} data - The data to log
     *
     * @return {integer} Send Error Code
     */
    function write(data) {
        local d = date();
        local ts = format("%04d-%02d-%02d %02d:%02d:%02d", d.year, d.month+1, d.day, d.hour, d.min, d.sec);
        _uart.write(ts + " " + data + "\n\r");
        return server.log(data);
    }
}

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


// Duration of a signal, in seconds
const LI_SIGNAL_DURATION = 1.0;
// Duration of a gap (delay) between signals, in seconds
const LI_GAP_DURATION = 0.2;
// Maximum repeats of the same event in a row
const LI_MAX_EVENT_REPEATS = 3;

// Event type for indication
enum LI_EVENT_TYPE {
    // Format: 0xRGB. E.g., 0x010 = GREEN, 0x110 = YELLOW
    // Green
    NEW_MSG = 0x010,
    // Red
    ALERT_SHOCK = 0x100,
    // White
    ALERT_MOTION_STARTED = 0x111,
    // Cyan
    ALERT_MOTION_STOPPED = 0x011,
    // Blue
    ALERT_TEMP_LOW = 0x001,
    // Yellow
    ALERT_TEMP_HIGH = 0x110,
    // Magenta
    MOVEMENT_DETECTED = 0x101
}

// LED indication class.
// Used for LED-indication of different events
class LedIndication {
    // Array of pins for blue, green and red (exactly this order) colors
    _rgbPins = null;
    // Promise used instead of a queue of signals for simplicity
    _indicationPromise = Promise.resolve(null);
    // The last indicated event type
    _lastEventType = null;
    // The number of repeats (in a row) of the last indicated event
    _lastEventRepeats = 0;

    /**
     * Constructor LED indication
     *
     * @param {object} rPin - Pin object used to control the red LED.
     * @param {object} gPin - Pin object used to control the green LED.
     * @param {object} bPin - Pin object used to control the blue LED.
     */
    constructor(rPin, gPin, bPin) {
        // Inverse order for convenience
        _rgbPins = [bPin, gPin, rPin];
    }

    /**
     * Indicate an event using LEDs
     *
     * @param {LI_EVENT_TYPE} eventType - The event type to indicate.
     */
    function indicate(eventType) {
        // There are 3 LEDS: blue, green, red
        const LI_LEDS_NUM = 3;

        if (eventType == _lastEventType) {
            _lastEventRepeats++;
        } else {
            _lastEventType = eventType;
            _lastEventRepeats = 0;
        }

        if (_lastEventRepeats >= LI_MAX_EVENT_REPEATS) {
            return;
        }

        _indicationPromise = _indicationPromise
        .finally(function(_) {
            // Turn on the required colors
            for (local i = 0; i < LI_LEDS_NUM && eventType > 0; i++) {
                (eventType & 1) && _rgbPins[i].configure(DIGITAL_OUT, 1);
                eventType = eventType >> 4;
            }

            return Promise(function(resolve, reject) {
                local stop = function() {
                    for (local i = 0; i < LI_LEDS_NUM; i++) {
                        _rgbPins[i].disable();
                    }

                    // Decrease the counter of repeats since we now have time for one more signal
                    (_lastEventRepeats > 0) && _lastEventRepeats--;

                    // Make a gap (delay) between signals for better perception
                    imp.wakeup(LI_GAP_DURATION, resolve);
                }.bindenv(this);

                // Turn off all colors after the signal duration
                imp.wakeup(LI_SIGNAL_DURATION, stop);
            }.bindenv(this));
        }.bindenv(this));
    }
}


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


// Flip Flop class.
// Used to work with flip flops as with a usual switch pin.
// Automatically clocks the flip flop on every action with the pin
class FlipFlop {
    _clkPin = null;
    _switchPin = null;

    /**
     * Constructor for Flip Flop class
     *
     * @param {object} clkPin - Hardware pin object that clocks the flip flop
     * @param {object} switchPin - Hardware pin object - the switch
     */
    constructor(clkPin, switchPin) {
        _clkPin = clkPin;
        _switchPin = switchPin;
    }

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

// Accelerometer's I2C bus
HW_ACCEL_I2C <- PowerSafeI2C(hardware.i2cLM);

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

function getValFromTable(tbl, path, defaultVal = null) {
    local pathSplit = split(path, "/");
    local curValue = tbl;

    for (local i = 0; i < pathSplit.len(); i++) {
        if (typeof(curValue) == "table" && pathSplit[i] in curValue) {
            curValue = curValue[pathSplit[i]];
        } else {
            return defaultVal;
        }
    }

    return curValue;
}

function getValsFromTable(tbl, keys) {
    if (tbl == null) {
        return {};
    }

    local res = {};

    foreach (key in keys) {
        (key in tbl) && (res[key] <- tbl[key]);
    }

    return res;
}

// Returns null if the object passed has zero length
function nullEmpty(obj) {
    if (obj == null || obj.len() == 0) {
        return null;
    }

    return obj;
}

function mixTables(src, dst) {
    if (src == null) {
        return dst;
    }

    foreach (k, v in src) {
        dst[k] <- v;
    }

    return dst;
}

function deepEqual(value1, value2, level = 0) {
    if (level > 32) {
        throw "Possible cyclic reference";
    }

    if (value1 == value2) {
        return true;
    }

    local type1 = type(value1);
    local type2 = type(value2);

    if (type1 == "class" || type2 == "class") {
        throw "Unsupported type";
    }

    if (type1 != type2) {
        return false;
    }

    switch (type1) {
        case "table":
        case "array":
            if (value1.len() != value2.len()) {
                return false;
            }

            foreach (k, v in value1) {
                if (!(k in value2) || !deepEqual(v, value2[k], level + 1)) {
                    return false;
                }
            }

            return true;
        default:
            return false;
    }
}

function tableFullCopy(tbl) {
    // NOTE: This may be suboptimal. May need to be improved
    return Serializer.deserialize(Serializer.serialize(tbl));
}
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


// ProductionManager's user config field
const PMGR_USER_CONFIG_FIELD = "ProductionManager";
// Period (sec) of checking for new deployments
const PMGR_CHECK_UPDATES_PERIOD = 3600;
// Maximum length of error saved when error flag is set
const PMGR_MAX_ERROR_LEN = 512;
// Connection timeout (sec)
const PMGR_CONNECT_TIMEOUT = 240;
// Server.flush timeout (sec)
const PMGR_FLUSH_TIMEOUT = 5;
// Send timeout for server.setsendtimeoutpolicy() (sec)
const PMGR_SEND_TIMEOUT = 3;

// Implements useful in production features:
// - Emergency mode (If an unhandled error occurred, device goes to sleep and periodically connects to the server waiting for a SW update)
// - Shipping mode (When released from the factory, the device sleeps until it is woken up by the end-user)
class ProductionManager {
    _debugOn = false;
    _startApp = null;
    _shippingMode = false;
    _isNewDeployment = false;

    /**
     * Constructor for Production Manager
     *
     * @param {function} startAppFunc - The function to be called to start the main application
     * @param {boolean} [shippingMode = false] - Enable shipping mode
     */
    constructor(startAppFunc, shippingMode = false) {
        _startApp = @() imp.wakeup(0, startAppFunc);
        _shippingMode = shippingMode;
    }

    /**
     * Start the manager. It will check the conditions and either start the main application or go to sleep.
     * This method must be called first
     */
    function start() {
        // Maximum sleep time (sec) used for shipping mode
        const PMGR_MAX_SLEEP_TIME = 2419198;

        // NOTE: The app may override this handler but it must call enterEmergencyMode in case of a runtime error
        imp.onunhandledexception(_onUnhandledException.bindenv(this));
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, PMGR_SEND_TIMEOUT);

        local data = _getOrInitializeData();

        if (data.errorFlag && data.deploymentID == __EI.DEPLOYMENT_ID) {
            if (server.isconnected()) {
                // No new deployment was detected
                _printLastErrorAndSleep(data.lastError);
            } else {
                local onConnect = function(_) {
                    _printLastErrorAndSleep(data.lastError);
                }.bindenv(this);

                // Connect to check for a new deployment
                server.connect(onConnect, PMGR_CONNECT_TIMEOUT);
            }

            return;
        } else if (data.deploymentID != __EI.DEPLOYMENT_ID) {
            // NOTE: The first code deploy will not be recognized as a new deploy!
            _info("New deployment detected!");
            _isNewDeployment = true;
            data = _initialData(!_shippingMode || data.shipped);
            _storeData(data);
        }

        if (_shippingMode && !data.shipped) {
            _info("Shipping mode is ON and the device has not been shipped yet");
            _sleep(PMGR_MAX_SLEEP_TIME);
        } else {
            _startApp();
        }
    }

    /**
     * This method should be called when the device has been shipped (if shipping mode is enabled)
     */
    function shipped() {
        local data = _getOrInitializeData();

        if (data.shipped) {
            return;
        }

        _info("The device has just been shipped! Starting the main application..");

        // Set "shipped" flag
        data.shipped = true;
        _storeData(data);

        // Restart to run the application
        server.flush(PMGR_FLUSH_TIMEOUT);
        imp.reset();
    }

    /**
     * Manually enter the Emergency mode
     *
     * @param {string} [error] - The error that caused entering the Emergency mode
     */
    function enterEmergencyMode(error = null) {
        _setErrorFlag(error);
        server.flush(PMGR_FLUSH_TIMEOUT);
        imp.reset();
    }

    /**
     * Check if new code has just been deployed (i.e. were no reboots after the deployment)
     *
     * @return {boolean} True if new code has just been deployed
     */
    function isNewDeployment() {
        return _isNewDeployment;
    }

    /**
     * Turn on/off the debug logging
     *
     * @param {boolean} value - True to turn on the debug logging, otherwise false
     */
    function setDebug(value) {
        _debugOn = value;
    }

    /**
     * Print the last saved error (if any) and go to sleep
     *
     * @param {table | null} lastError - Last saved error with timestamp and description
     */
    function _printLastErrorAndSleep(lastError) {
        // Timeout of checking for updates, in seconds
        const PM_CHECK_UPDATES_TIMEOUT = 5;

        if (lastError && "ts" in lastError && "desc" in lastError) {
            _info(format("Last error (at %d): \"%s\"", lastError.ts, lastError.desc));
        }

        // After the timeout, sleep until the next update (code deploy) check
        _sleep(PMGR_CHECK_UPDATES_PERIOD, PM_CHECK_UPDATES_TIMEOUT);
    }

    /**
     * Go to sleep once Squirrel VM is idle
     *
     * @param {float} sleepTime - The deep sleep duration in seconds
     * @param {float} [delay] - Delay before sleep, in seconds
     */
    function _sleep(sleepTime, delay = 0) {
        local sleep = function() {
            _info("Going to sleep for " + sleepTime + " seconds");
            server.sleepfor(sleepTime);
        }.bindenv(this);

        imp.wakeup(delay, @() imp.onidle(sleep));
    }

    /**
     * Global handler for exceptions
     *
     * @param {string} error - The exception description
     */
    function _onUnhandledException(error) {
        _error("Globally caught error: " + error);
        _setErrorFlag(error);
    }

    /**
     * Create and return the initial user configuration data
     *
     * @param {boolean} shipped - True if the device is already shipped or shipping mode is disabled
     *
     * @return {table} The initial user configuration data
     */
    function _initialData(shipped) {
        return {
            "errorFlag": false,
            "lastError": null,
            "shipped": shipped,
            "deploymentID": __EI.DEPLOYMENT_ID
        };
    }

    /**
     * Get (if exists) or initialize (create and save) user configuration data
     *
     * @return {table} Parsed and checked user configuration data
     */
    function _getOrInitializeData() {
        try {
            local userConf = _readUserConf();

            if (userConf == null) {
                _storeData(_initialData(false));
                return _initialData(false);
            }

            local fields = ["errorFlag", "lastError", "shipped", "deploymentID"];
            local data = userConf[PMGR_USER_CONFIG_FIELD];

            foreach (field in fields) {
                // This will throw an exception if no such field found
                data[field];
            }

            return data;
        } catch (err) {
            _error("Error during parsing user configuration: " + err);
        }

        _storeData(_initialData(_shippingMode));
        return _initialData(_shippingMode);
    }

    /**
     * Store user configuration data
     *
     * @param {table} data - The user configuration data to be stored for this module
     */
    function _storeData(data) {
        local userConf = {};

        try {
            userConf = _readUserConf() || {};
        } catch (err) {
            _error("Error during parsing user configuration: " + err);
            _debug("Creating user configuration from scratch..");
        }

        userConf[PMGR_USER_CONFIG_FIELD] <- data;

        local dataStr = JSONEncoder.encode(userConf);
        _debug("Storing new user configuration: " + dataStr);

        try {
            imp.setuserconfiguration(dataStr);
        } catch (err) {
            _error(err);
        }
    }

    /**
     * Set the error flag which will restrict running the main application on the next boot
     *
     * @param {string} error - The error description
     */
    function _setErrorFlag(error) {
        local data = _getOrInitializeData();

        // By this update we update the userConf object (see above)
        data.errorFlag = true;

        if (typeof(error) == "string") {
            if (error.len() > PMGR_MAX_ERROR_LEN) {
                error = error.slice(0, PMGR_MAX_ERROR_LEN);
            }

            data.lastError = {
                "ts": time(),
                "desc": error
            };
        }

        _storeData(data);
    }

    /**
     * Read the user configuration and parse it (JSON)
     *
     * @return {table | null} The user configuration converted from JSON to a Squirrel table
     *      or null if there was no user configuration saved
     */
    function _readUserConf() {
        local config = imp.getuserconfiguration();

        if (config == null) {
            _debug("User configuration is empty");
            return null;
        }

        config = config.tostring();
        // NOTE: This may print a binary string if something non-printable is in the config
        _debug("User configuration: " + config);

        config = JSONParser.parse(config);

        if (typeof config != "table") {
            throw "table expected";
        }

        return config;
    }

    /**
     * Log a debug message if debug logging is on
     *
     * @param {string} msg - The message to log
     */
    function _debug(msg) {
        _debugOn && server.log("[ProductionManager] " + msg);
    }

    /**
     * Log an info message
     *
     * @param {string} msg - The message to log
     */
    function _info(msg) {
        server.log("[ProductionManager] " + msg);
    }

    /**
     * Log an error message
     *
     * @param {string} msg - The message to log
     */
    function _error(msg) {
        server.error("[ProductionManager] " + msg);
    }
}

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


// File names used by Cfg Manager
enum CFGM_FILE_NAMES {
    CFG = "cfg"
}

// Configuration Manager class:
// - Passes the configuration (default or custom) to start modules
// - Receives configuration updates from the agent
// - Finds a diff between the current and the new configurations
// - Passes the diff to the modules
// - Stores the latest configuration version
// - Reports the latest configuration version to the agent
class CfgManager {
    // Array of modules to be configured
    _modules = null;
    // SPIFlashFileSystem storage for configuration
    _storage = null;
    // Promise or null
    _processingCfg = null;
    // The actual (already applied) configuration
    _actualCfg = null;

    /**
     * Constructor for Configuration Manager class
     *
     * @param {array} modules - Application modules (must have start() and updateCfg() methods)
     */
    constructor(modules) {
        _modules = modules;

        // Create storage
        _storage = SPIFlashFileSystem(HW_CFGM_SFFS_START_ADDR, HW_CFGM_SFFS_END_ADDR);
        _storage.init();
    }

    /**
     * Load saved configuration or the default one and start modules, report the configuration
     */
    function start() {
        // Let's keep the connection to be able to report the configuration once it is deployed
        cm.keepConnection("CfgManager", true);

        rm.on(APP_RM_MSG_NAME.CFG, _onCfgUpdate.bindenv(this));

        local defaultCfgUsed = false;
        local cfg = _loadCfg() || (defaultCfgUsed = true) && _defaultCfg();
        local promises = [];

        try {
            ::info(format("Deploying the %s configuration with updateId: %s",
                          defaultCfgUsed ? "default" : "saved", cfg.updateId), "CfgManager");

            _applyDebugSettings(cfg);

            foreach (module in _modules) {
                promises.push(module.start(cfg));
            }
        } catch (err) {
            promises.push(Promise.reject(err));
        }

        _processingCfg = Promise.all(promises)
        .then(function(_) {
            ::info("The configuration has been successfully deployed", "CfgManager");
            _actualCfg = cfg;

            // Send the actual cfg to the agent
            _reportCfg();
        }.bindenv(this), function(err) {
            ::error("Couldn't deploy the configuration: " + err, "CfgManager");

            if (defaultCfgUsed) {
                // This will raise the error flag and reboot the imp. This call doesn't return!
                pm.enterEmergencyMode();
            } else {
                ::debug(cfg, "CfgManager");

                // Erase both the main cfg and the debug one
                _eraseCfg();
                // This will reboot the imp. This call doesn't return!
                _reboot();
            }
        }.bindenv(this))
        .finally(function(_) {
            cm.keepConnection("CfgManager", false);
            _processingCfg = null;
        }.bindenv(this));
    }

    function _onCfgUpdate(msg, customAck) {
        // Let's keep the connection to be able to report the configuration once it is deployed
        cm.keepConnection("CfgManager", true);

        local cfgUpdate = msg.data;
        local updateId = cfgUpdate.updateId;

        ::info("Configuration update received: " + updateId, "CfgManager");

        _processingCfg = (_processingCfg || Promise.resolve(null))
        .then(function(_) {
            ::debug("Starting processing " + updateId + " cfg update..", "CfgManager");

            if (updateId == _actualCfg.updateId) {
                ::info("Configuration update has the same updateId as the actual cfg", "CfgManager");
                // Resolve with null to indicate that the update hasn't been deployed due to no sense
                return Promise.resolve(null);
            }

            _diff(cfgUpdate, _actualCfg);
            _applyDebugSettings(cfgUpdate);

            local promises = [];

            foreach (module in _modules) {
                promises.push(module.updateCfg(cfgUpdate));
            }

            return Promise.all(promises);
        }.bindenv(this))
        .then(function(result) {
            if (result == null) {
                // No cfg deploy has been done
                return;
            }

            ::info("The configuration update has been successfully deployed", "CfgManager");

            // Apply the update (diff) to the actual cfg
            _applyDiff(cfgUpdate, _actualCfg);
            // Save the actual cfg in the storage
            _saveCfg();
            // Send the actual cfg to the agent
            _reportCfg();
        }.bindenv(this), function(err) {
            ::error("Couldn't deploy the configuration update: " + err, "CfgManager");
            _reboot();
        }.bindenv(this))
        .finally(function(_) {
            cm.keepConnection("CfgManager", false);
            _processingCfg = null;
        }.bindenv(this));
    }

    function _applyDebugSettings(cfg) {
        if (!("debug" in cfg)) {
            return;
        }

        local debugSettings = cfg.debug;

        ::debug("Applying debug settings..", "CfgManager");

        if ("logLevel" in debugSettings) {
            ::info("Setting log level: " + debugSettings.logLevel, "CfgManager");
            Logger.setLogLevelStr(debugSettings.logLevel);
        }
    }

    function _reportCfg() {
        ::debug("Reporting cfg..", "CfgManager");

        local cfgReport = {
            "configuration": tableFullCopy(_actualCfg)
            "description": {
                "cfgTimestamp": time()
            }
        };

        rm.send(APP_RM_MSG_NAME.CFG, cfgReport, RM_IMPORTANCE_HIGH);
    }

    function _reboot() {
        const CFGM_FLUSH_TIMEOUT = 5;

        server.flush(CFGM_FLUSH_TIMEOUT);
        server.restart();
    }

    function _diff(cfgUpdate, actualCfg, path = "") {
        // The list of the paths which should be handled in a special way when making or applying a diff.
        // When making a diff, we just don't touch these paths (and their sub-paths) in the cfg update - leave them as is.
        // When applying a diff, we just fully replace these paths (their values) in the actual cfg with the values from the diff.
        // Every path must be prefixed with "^" and postfixed with "$". Every segment of a path must be prefixed with "/".
        // NOTE: It's assumed that "^", "/" and "$" are not used in keys of a configuration
        const CFGM_DIFF_SPECIAL_PATHS = @"^/locationTracking/bleDevices/generic$
                                          ^/locationTracking/bleDevices/iBeacon$";

        local keysToRemove = [];

        foreach (k, v in cfgUpdate) {
            // The full path which includes the key currently considered
            local fullPath = path + "/" + k;
            // Check if this path should be skipped
            if (!(k in actualCfg) || CFGM_DIFF_SPECIAL_PATHS.find("^" + fullPath + "$") != null) {
                continue;
            }

            // We assume that configuration can only contain nested tables, not arrays
            if (type(v) == "table") {
                // Make a diff from a nested table
                _diff(v, actualCfg[k], fullPath);
                // If the table is empty after making a diff, we just remove it as it doesn't make sense anymore
                (v.len() == 0) && keysToRemove.push(k);
            } else if (v == actualCfg[k]) {
                keysToRemove.push(k);
            }
        }

        foreach (k in keysToRemove) {
            delete cfgUpdate[k];
        }
    }

    function _applyDiff(diff, actualCfg, path = "") {
        foreach (k, v in diff) {
            // The full path which includes the key currently considered
            local fullPath = path + "/" + k;
            // Check if this path should be fully replaced in the actual cfg
            local fullyReplace = !(k in actualCfg) || CFGM_DIFF_SPECIAL_PATHS.find("^" + fullPath + "$") != null;

            // We assume that configuration can only contain nested tables, not arrays
            if (type(v) == "table" && !fullyReplace) {
                // Make a diff from a nested table
                _applyDiff(v, actualCfg[k], fullPath);
            } else {
                actualCfg[k] <- v;
            }
        }
    }

    function _defaultCfg() {
        try {
            return JSONParser.parse(__VARS.DEFAULT_CFG).configuration;
        } catch (err) {
            throw "Can't parse the default configuration: " + err;
        }
    }

    // -------------------- STORAGE METHODS -------------------- //

    function _saveCfg(cfg = null, fileName = CFGM_FILE_NAMES.CFG) {
        ::debug("Saving cfg (fileName = " + fileName + ")..", "CfgManager");

        cfg = cfg || _actualCfg;

        _eraseCfg(fileName);

        try {
            local file = _storage.open(fileName, "w");
            file.write(Serializer.serialize(cfg));
            file.close();
        } catch (err) {
            ::error(format("Couldn't save cfg (file name = %s): %s", fileName, err), "CfgManager");
        }
    }

    function _loadCfg(fileName = CFGM_FILE_NAMES.CFG) {
        try {
            if (_storage.fileExists(fileName)) {
                local file = _storage.open(fileName, "r");
                local data = file.read();
                file.close();
                return Serializer.deserialize(data);
            }
        } catch (err) {
            ::error(format("Couldn't load cfg (file name = %s): %s", fileName, err), "CfgManager");
        }

        return null;
    }

    function _eraseCfg(fileName = CFGM_FILE_NAMES.CFG) {
        try {
            // Erase the existing file if any
            _storage.fileExists(fileName) && _storage.eraseFile(fileName);
        } catch (err) {
            ::error(format("Couldn't erase cfg (file name = %s): %s", fileName, err), "CfgManager");
        }
    }
}

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


// Customized ConnectionManager library
class CustomConnectionManager extends ConnectionManager {
    _autoDisconnectDelay = null;
    _maxConnectedTime = null;

    _consumers = null;
    _connectPromise = null;
    _connectTime = null;
    _disconnectTimer = null;

    /**
     * Constructor for Customized Connection Manager
     *
     * @param {table} [settings = {}] - Key-value table with optional settings.
     *
     * An exception may be thrown in case of wrong settings.
     */
    constructor(settings = {}) {
        // Automatically disconnect if the connection is not consumed for some time
        _autoDisconnectDelay = "autoDisconnectDelay" in settings ? settings.autoDisconnectDelay : null;
        // Automatically disconnect if the connection is up for too long (for power saving purposes)
        _maxConnectedTime = "maxConnectedTime" in settings ? settings.maxConnectedTime : null;

        if ("stayConnected" in settings && settings.stayConnected && (_autoDisconnectDelay != null || _maxConnectedTime != null)) {
            throw "stayConnected option cannot be used together with automatic disconnection features";
        }

        base.constructor(settings);
        _consumers = [];

        if (_connected) {
            _connectTime = hardware.millis();
            _setDisconnectTimer();
        }

        onConnect(_onConnectCb.bindenv(this), "CustomConnectionManager");
        onTimeout(_onConnectionTimeoutCb.bindenv(this), "CustomConnectionManager");
        onDisconnect(_onDisconnectCb.bindenv(this), "CustomConnectionManager");

        // NOTE: It may worth adding a periodic connection feature to this module
    }

    /**
     * Connect to the server. Set the disconnection timer if needed.
     * If already connected:
     *   - the onConnect handler will NOT be called
     *   - if the disconnection timer was set, it will be cancelled and set again
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects with if the operation failed
     */
    function connect() {
        if (_connected) {
            _setDisconnectTimer();
            return Promise.resolve(null);
        }

        if (_connectPromise) {
            return _connectPromise;
        }

        ::info("Connecting..", "CustomConnectionManager");

        local baseConnect = base.connect;

        _connectPromise = Promise(function(resolve, reject) {
            onConnect(resolve, "CustomConnectionManager.connect");
            onTimeout(reject, "CustomConnectionManager.connect");
            onDisconnect(reject, "CustomConnectionManager.connect");

            baseConnect();
        }.bindenv(this));

        // A workaround to avoid "Unhandled promise rejection" message in case of connection failure
        _connectPromise
        .fail(@(_) null);

        return _connectPromise;
    }

    /**
     * Keep/don't keep the connection (if established) while a consumer is using it.
     * If there is at least one consumer using the connection, automatic disconnection is deactivated.
     * Once there are no consumers, automatic disconnection is activated.
     * May be called when connected and when disconnected as well
     *
     * @param {string} consumerId - Consumer's identificator.
     * @param {boolean} keep - Flag indicating if the connection should be kept for this consumer.
     */
    function keepConnection(consumerId, keep) {
        // It doesn't make sense to manage the list of connection consumers if the autoDisconnectDelay option is disabled
        if (_autoDisconnectDelay == null) {
            return;
        }

        local idx = _consumers.find(consumerId);

        if (keep && idx == null) {
            ::debug("Connection will be kept for " + consumerId, "CustomConnectionManager");
            _consumers.push(consumerId);
            _setDisconnectTimer();
        } else if (!keep && idx != null) {
            ::debug("Connection will not be kept for " + consumerId, "CustomConnectionManager");
            _consumers.remove(idx);
            _setDisconnectTimer();
        }
    }

    /**
     * Callback called when a connection to the server has been established
     * NOTE: This function can't be renamed to _onConnect
     */
    function _onConnectCb() {
        ::info("Connected", "CustomConnectionManager");
        _connectPromise = null;
        _connectTime = hardware.millis();

        _setDisconnectTimer();
    }

    /**
     * Callback called when a connection to the server has been timed out
     * NOTE: This function can't be renamed to _onConnectionTimeout
     */
    function _onConnectionTimeoutCb() {
        ::info("Connection timeout", "CustomConnectionManager");
        _connectPromise = null;
    }

    /**
     * Callback called when a connection to the server has been broken
     * NOTE: This function can't be renamed to _onDisconnect
     *
     * @param {boolean} expected - Flag indicating if the disconnection was expected
     */
    function _onDisconnectCb(expected) {
        ::info(expected ? "Disconnected" : "Disconnected unexpectedly", "CustomConnectionManager");
        _disconnectTimer && imp.cancelwakeup(_disconnectTimer);
        _connectPromise = null;
        _connectTime = null;
    }

    /**
     * Set the disconnection timer according to the parameters of automatic disconnection features
     */
    function _setDisconnectTimer() {
        if (_connectTime == null) {
            return;
        }

        local delay = null;

        if (_maxConnectedTime != null) {
            delay = _maxConnectedTime - (hardware.millis() - _connectTime) / 1000.0;
            delay < 0 && (delay = 0);
        }

        if (_autoDisconnectDelay != null && _consumers.len() == 0) {
            delay = (delay == null || delay > _autoDisconnectDelay) ? _autoDisconnectDelay : delay;
        }

        _disconnectTimer && imp.cancelwakeup(_disconnectTimer);

        if (delay != null) {
            ::debug(format("Disconnection scheduled in %d seconds", delay), "CustomConnectionManager");

            local onDisconnectTimer = function() {
                ::info("Disconnecting now..", "CustomConnectionManager");
                disconnect();
            }.bindenv(this);

            _disconnectTimer = imp.wakeup(delay, onDisconnectTimer);
        }
    }
}

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


// Customized ReplayMessenger library

// Maximum number of recent messages to look into when searching the maximum message ID
const CRM_MAX_ID_SEARCH_DEPTH = 20;
// Minimum free memory (bytes) to allow SPI flash logger reading and resending persisted messages
const CRM_FREE_MEM_THRESHOLD = 65536;
// Custom value for MSGR_QUEUE_CHECK_INTERVAL_SEC
const CRM_QUEUE_CHECK_INTERVAL_SEC = 1.0;
// Custom value for RM_RESEND_RATE_LIMIT_PCT
const CRM_RESEND_RATE_LIMIT_PCT = 80;

class CustomReplayMessenger extends ReplayMessenger {
    _persistedMessagesPending = false;
    _eraseAllPending = false;
    _onAckCbs = null;
    _onAckDefaultCb = null;
    _onFailCbs = null;
    _onFailDefaultCb = null;

    /**
     * Custom Replay Messenger constructor
     *
     * @param {SPIFlashLogger} spiFlashLogger - Instance of spiFlashLogger which will be used to store messages
     * @param {table} [options] - Key-value table with optional settings
     */
    constructor(spiFlashLogger, options = {}) {
        // Provide any ID to prevent the standart algorithm of searching of the next usable ID
        options.firstMsgId <- 0;

        base.constructor(spiFlashLogger, cm, options);

        // Override the resend rate variable using our custom constant
        _maxResendRate = _maxRate * CRM_RESEND_RATE_LIMIT_PCT / 100;

        // We want to block any background RM activity until the initialization is done
        _readingInProcess = true;

        // In the custom version, we want to have an individual ACK and Fail callback for each message name
        _onAck = _onAckHandler;
        _onAckCbs = {};
        _onFail = _onFailHandler;
        _onFailCbs = {};
    }

    /**
     * Initialize. Read several last saved messages to determine the next ID, which can be used for new messages
     *
     * @param {function} onDone - Callback to be called when initialization is done
     */
    function init(onDone) {
        local maxId = -1;
        local msgRead = 0;

        _log(format("Reading %d recent messages to find the maximum message ID...", CRM_MAX_ID_SEARCH_DEPTH));
        local start = hardware.millis();

        local onData = function(payload, address, next) {
            local id = -1;

            try {
                id = payload[RM_COMPRESSED_MSG_PAYLOAD]["id"];
            } catch (err) {
                ::error("Corrupted message detected during initialization: " + err, "CustomReplayMessenger");
                _spiFL.erase(address);
                next();
                return;
            }

            maxId = id > maxId ? id : maxId;
            msgRead++;
            next(msgRead < CRM_MAX_ID_SEARCH_DEPTH);
        }.bindenv(this);

        local onFinish = function() {
            local elapsed = hardware.millis() - start;
            _log(format("The maximum message ID has been found: %d. Elapsed: %dms", maxId, elapsed));

            _nextId = maxId + 1;
            _readingInProcess = false;
            _persistedMessagesPending = msgRead > 0;
            _setTimer();
            onDone();
        }.bindenv(this);

        // We are going to read CRM_MAX_ID_SEARCH_DEPTH messages starting from the most recent one
        _spiFL.read(onData, onFinish, -1);
    }

    /**
     * Sets the name-specific ACK callback which will be called when an ACK received for a message with this name
     *
     * @param {function | null} onDone - Callback to be called when an ACK received. If null passed, remove the callback (if set)
     * @param {string} [name] - Message name. If not passed, the callback will be used as a default one
     */
    function onAck(cb, name = null) {
        if (name == null) {
            _onAckDefaultCb = cb;
        } else if (cb) {
            _onAckCbs[name] <- cb;
        } else if (name in _onAckCbs) {
            delete _onAckCbs[name];
        }
    }

    /**
     * Sets the name-specific fail callback which will be called when a message with this name has been failed to send
     *
     * @param {function | null} onDone - Callback to be called when a message has been failed to send.
     *                            If null passed, remove the callback (if set)
     * @param {string} [name] - Message name. If not passed, the callback will be used as a default one
     */
    function onFail(cb, name = null) {
        if (name == null) {
            _onFailDefaultCb = cb;
        } else if (cb) {
            _onFailCbs[name] <- cb;
        } else if (name in _onFailCbs) {
            delete _onFailCbs[name];
        }
    }

    // -------------------- PRIVATE METHODS -------------------- //

    // Sends the message (and immediately persists it if needed) and restarts the timer for processing the queues
    function _send(msg) {
        // Check if the message has importance = RM_IMPORTANCE_CRITICAL and not yet persisted
        if (msg._importance == RM_IMPORTANCE_CRITICAL && !_isMsgPersisted(msg)) {
            _persistMessage(msg);
        }

        local id = msg.payload.id;
        _log("Trying to send msg. Id: " + id);

        local now = _monotonicMillis();
        if (now - 1000 > _lastRateMeasured || now < _lastRateMeasured) {
            // Reset the counters if the timer's overflowed or
            // more than a second passed from the last measurement
            _rateCounter = 0;
            _lastRateMeasured = now;
        } else if (_rateCounter >= _maxRate) {
            // Rate limit exceeded, raise an error
            _onSendFail(msg, MSGR_ERR_RATE_LIMIT_EXCEEDED);
            return;
        }

        // Try to send
        local payload = msg.payload;
        local err = _partner.send(MSGR_MESSAGE_TYPE_DATA, payload);
        if (!err) {
            // Send complete
            _log("Sent. Id: " + id);

            _rateCounter++;
            // Set sent time, update sentQueue and restart timer
            msg._sentTime = time();
            _sentQueue[id] <- msg;

            _log(format("_sentQueue: %d, _persistMessagesQueue: %d, _eraseQueue: %d", _sentQueue.len(), _persistMessagesQueue.len(), _eraseQueue.len()));

            _setTimer();
        } else {
            _log("Sending error. Code: " + err);
            // Sending failed
            _onSendFail(msg, MSGR_ERR_NO_CONNECTION);
        }
    }

    function _onAckHandler(msg, data) {
        local name = msg.payload.name;

        if (name in _onAckCbs) {
            _onAckCbs[name](msg, data);
        } else {
            _onAckDefaultCb && _onAckDefaultCb(msg, data);
        }
    }

    function _onFailHandler(msg, error) {
        local name = msg.payload.name;

        if (name in _onFailCbs) {
            _onFailCbs[name](msg, error);
        } else {
            _onFailDefaultCb && _onFailDefaultCb(msg, error);
        }
    }

    // Returns true if send limits are not exceeded, otherwise false
    function _checkSendLimits() {
        local now = _monotonicMillis();
        if (now - 1000 > _lastRateMeasured || now < _lastRateMeasured) {
            // Reset the counters if the timer's overflowed or
            // more than a second passed from the last measurement
            _rateCounter = 0;
            _lastRateMeasured = now;
        } else if (_rateCounter >= _maxRate) {
            // Rate limit exceeded
            _log("Send rate limit exceeded");
            return false;
        }

        return true;
    }

    function _isAllProcessed() {
        if (_sentQueue.len() != 0) {
            return false;
        }

        // We can't process persisted messages if we are offline
        return !_cm.isConnected() || !_persistedMessagesPending;
    }

    // Processes both _sentQueue and the messages persisted on the flash
    function _processQueues() {
        // Clean up the timer
        _queueTimer = null;

        local now = time();

        // Call onFail for timed out messages
        foreach (id, msg in _sentQueue) {
            local ackTimeout = msg._ackTimeout ? msg._ackTimeout : _ackTimeout;
            if (now - msg._sentTime >= ackTimeout) {
                _onSendFail(msg, MSGR_ERR_ACK_TIMEOUT);
            }
        }

        _processPersistedMessages();

        // Restart the timer if there is something pending
        if (!_isAllProcessed()) {
            _setTimer();
            // If Replay Messenger has unsent or unacknowledged messages, keep the connection for it
            cm.keepConnection("CustomReplayMessenger", true);
        } else {
            // If Replay Messenger is idle (has no unsent or unacknowledged messages), it doesn't need the connection anymore
            cm.keepConnection("CustomReplayMessenger", false);
        }
    }

    // Processes the messages persisted on the flash
    function _processPersistedMessages() {
        if (_readingInProcess || !_persistedMessagesPending || imp.getmemoryfree() < CRM_FREE_MEM_THRESHOLD) {
            return;
        }

        local sectorToCleanup = null;
        local messagesExist = false;

        if (_cleanupNeeded) {
            sectorToCleanup = _flDimensions["start"] + (_spiFL.getPosition() / _flSectorSize + 1) * _flSectorSize;

            if (sectorToCleanup >= _flDimensions["end"]) {
                sectorToCleanup = _flDimensions["start"];
            }
        } else if (!_cm.isConnected() || !_checkResendLimits()) {
            return;
        }

        local onData = function(messagePayload, address, next) {
            local msg = null;

            try {
                // Create a message from payload
                msg = _messageFromFlash(messagePayload, address);
            } catch (err) {
                ::error("Corrupted message detected during processing messages: " + err, "CustomReplayMessenger");
                _spiFL.erase(address);
                next();
                return;
            }

            messagesExist = true;
            local id = msg.payload.id;

            local needNextMsg = _cleanupPersistedMsg(sectorToCleanup, address, id, msg) ||
                                _resendPersistedMsg(address, id, msg);

            needNextMsg = needNextMsg && (imp.getmemoryfree() >= CRM_FREE_MEM_THRESHOLD);

            next(needNextMsg);
        }.bindenv(this);

        local onFinish = function() {
            _log("Processing persisted messages: finished");

            _persistedMessagesPending = messagesExist;

            if (sectorToCleanup != null) {
                _onCleanupDone();
            }
            _onReadingFinished();
        }.bindenv(this);

        _log("Processing persisted messages...");
        _readingInProcess = true;
        _spiFL.read(onData, onFinish);
    }

    // Callback called when async reading (in the _processPersistedMessages method) is finished
    function _onReadingFinished() {
        _readingInProcess = false;

        if (_eraseAllPending) {
            _eraseAllPending = false;
            _spiFL.eraseAll(true);
            ::debug("Flash logger erased", "CustomReplayMessenger");

            _eraseQueue = {};
            _cleanupNeeded = false;
            _processPersistMessagesQueue();
        }

        // Process the queue of messages to be erased
        if (_eraseQueue.len() > 0) {
            _log("Processing the queue of messages to be erased...");
            foreach (id, address in _eraseQueue) {
                _log("Message erased. Id: " + id);
                _spiFL.erase(address);
            }
            _eraseQueue = {};
            _log("Processing the queue of messages to be erased: finished");
        }

        if (_cleanupNeeded) {
            // Restart the processing in order to cleanup the next sector
            _processPersistedMessages();
        }
    }

    // Persists the message if there is enough space in the current sector.
    // If not, adds the message to the _persistMessagesQueue queue (if `enqueue` is `true`).
    // Returns true if the message has been persisted, otherwise false
    function _persistMessage(msg, enqueue = true) {
        if (_cleanupNeeded) {
            if (enqueue) {
                _log("Message added to the queue to be persisted later. Id: " + msg.payload.id);
                _persistMessagesQueue.push(msg);

                _log(format("_sentQueue: %d, _persistMessagesQueue: %d, _eraseQueue: %d", _sentQueue.len(), _persistMessagesQueue.len(), _eraseQueue.len()));
            }
            return false;
        }

        local payload = _prepareMsgToPersist(msg);

        if (_isEnoughSpace(payload)) {
            msg._address = _spiFL.getPosition();

            try {
                _spiFL.write(payload);
            } catch (err) {
                ::error("Couldn't persist a message: " + err, "CustomReplayMessenger");
                ::error("Erasing the flash logger!", "CustomReplayMessenger");

                if (_readingInProcess) {
                    ::debug("Flash logger will be erased once reading is finished", "CustomReplayMessenger");
                    _eraseAllPending = true;
                    enqueue && _persistMessagesQueue.push(msg);
                } else {
                    _spiFL.eraseAll(true);
                    ::debug("Flash logger erased", "CustomReplayMessenger");
                    // Instead of enqueuing, we try to write it again because erasing must help. If it doesn't help, we will just drop this message
                    enqueue && _persistMessage(msg, false);
                }

                _log(format("_sentQueue: %d, _persistMessagesQueue: %d, _eraseQueue: %d", _sentQueue.len(), _persistMessagesQueue.len(), _eraseQueue.len()));
                return false;
            }

            _log("Message persisted. Id: " + msg.payload.id);
            _persistedMessagesPending = true;
            return true;
        } else {
            _log("Need to clean up the next sector");
            _cleanupNeeded = true;
            if (enqueue) {
                _log("Message added to the queue to be persisted later. Id: " + msg.payload.id);
                _persistMessagesQueue.push(msg);

                _log(format("_sentQueue: %d, _persistMessagesQueue: %d, _eraseQueue: %d", _sentQueue.len(), _persistMessagesQueue.len(), _eraseQueue.len()));
            }
            _processPersistedMessages();
            return false;
        }
    }

    // Returns true if there is enough space in the current flash sector to persist the payload
    function _isEnoughSpace(payload) {
        local nextSector = (_spiFL.getPosition() / _flSectorSize + 1) * _flSectorSize;
        // NOTE: We need to access a private field for optimization
        // Correct work is guaranteed with "SPIFlashLogger.device.lib.nut:2.2.0"
        local payloadSize = _spiFL._serializer.sizeof(payload, SPIFLASHLOGGER_OBJECT_MARKER);

        if (_spiFL.getPosition() + payloadSize <= nextSector) {
            return true;
        } else {
            if (nextSector >= _flDimensions["end"] - _flDimensions["start"]) {
                nextSector = 0;
            }

            local nextSectorIdx = nextSector / _flSectorSize;
            // NOTE: We need to call a private method for optimization
            // Correct work is guaranteed with "SPIFlashLogger.device.lib.nut:2.2.0"
            local objectsStartCodes = _spiFL._getObjectsStartCodesForSector(nextSectorIdx);
            local nextSectorIsEmpty = objectsStartCodes == null || objectsStartCodes.len() == 0;
            return nextSectorIsEmpty;
        }
    }

    // Erases the message if no async reading is ongoing, otherwise puts it into the queue to erase later
    function _safeEraseMsg(id, msg) {
        if (!_readingInProcess) {
            _log("Message erased. Id: " + id);
            _spiFL.erase(msg._address);
        } else {
            _log("Message added to the queue to be erased later. Id: " + id);
            _eraseQueue[id] <- msg._address;

            _log(format("_sentQueue: %d, _persistMessagesQueue: %d, _eraseQueue: %d", _sentQueue.len(), _persistMessagesQueue.len(), _eraseQueue.len()));
        }
        msg._address = null;
    }

    // Sets a timer for processing queues
    function _setTimer() {
        if (_queueTimer) {
            // The timer is already running
            return;
        }
        _queueTimer = imp.wakeup(CRM_QUEUE_CHECK_INTERVAL_SEC,
                                _processQueues.bindenv(this));
    }

    // Implements debug logging. Sends the log message to the console output if "debug" configuration flag is set
    function _log(message) {
        if (_debug) {
            ::debug(message, "CustomReplayMessenger");
        }
    }
}

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


// Required BG96/95 AT Commands
enum AT_COMMAND {
    // Query the information of neighbour cells (Detailed information of base station)
    GET_QENG  = "AT+QENG=\"neighbourcell\"",
    // Query the information of serving cell (Detailed information of base station)
    GET_QENG_SERV_CELL  = "AT+QENG=\"servingcell\""
}

// Class to obtain cell towers info from BG96/95 modems.
// This code uses unofficial impOS features
// and is based on an unofficial example provided by Twilio
// Utilizes the following AT Commands:
// - QuecCell Commands:
//   - AT+QENG Switch on/off Engineering Mode
class BG9xCellInfo {

    /**
    * Get the network registration information from BG96/95
    *
    * @return {Table} The network registration information, or null on error.
    * Table fields include:
    * "radioType"                   - The mobile radio type: "gsm" or "lte"
    * "cellTowers"                  - Array of tables
    *     cellTowers[0]             - Table with information about the connected tower
    *         "locationAreaCode"    - Integer of the location area code  [0, 65535]
    *         "cellId"              - Integer cell ID
    *         "mobileCountryCode"   - Mobile country code string
    *         "mobileNetworkCode"   - Mobile network code string
    *     cellTowers[1 .. x]        - Table with information about the neighbor towers
    *                                 (optional)
    *         "locationAreaCode"    - Integer location area code [0, 65535]
    *         "cellId"              - Integer cell ID
    *         "mobileCountryCode"   - Mobile country code string
    *         "mobileNetworkCode"   - Mobile network code string
    *         "signalStrength"      - Signal strength string
    */
    function scanCellTowers() {
        local data = {
            "radioType": null,
            "cellTowers": []
        };

        ::debug("Scanning cell towers..", "BG9xCellInfo");

        try {
            local qengCmdResp = _writeAndParseAT(AT_COMMAND.GET_QENG_SERV_CELL);
            if ("error" in qengCmdResp) {
                throw "AT+QENG serving cell command returned error: " + qengCmdResp.error;
            }

            local srvCellRadioType = _qengExtractRadioType(qengCmdResp.data);

            switch (srvCellRadioType) {
                // This type is used by both BG96/95 modem
                case "GSM":
                    data.radioType = "gsm";
                    // +QENG:
                    // "servingscell",<state>,"GSM",<mcc>,
                    // <mnc>,<lac>,<cellid>,<bsic>,<arfcn>,<band>,<rxlev>,<txp>,
                    // <rla>,<drx>,<c1>,<c2>,<gprs>,<tch>,<ts>,<ta>,<maio>,<hsn>,<rxlevsub>,
                    // <rxlevfull>,<rxqualsub>,<rxqualfull>,<voicecodec>
                    data.cellTowers.append(_qengExtractServingCellGSM(qengCmdResp.data));
                    // Neighbor towers
                    // +QENG:
                    // "neighbourcell","GSM",<mcc>,<mnc>,<lac>,<cellid>,<bsic>,<arfcn>,
                    // <rxlev>,<c1>,<c2>,<c31>,<c32>
                    qengCmdResp = _writeAndParseATMultiline(AT_COMMAND.GET_QENG);
                    if ("error" in qengCmdResp) {
                        ::error("AT+QENG command returned error: " + qengCmdResp.error, "BG9xCellInfo");
                    } else {
                        data.cellTowers.extend(_qengExtractTowersInfo(qengCmdResp.data, srvCellRadioType));
                    }
                    break;
                // These types are used by BG96 modem
                case "CAT-M":
                case "CAT-NB":
                case "LTE":
                // These types are used by BG95 modem
                case "eMTC":
                case "NBIoT":
                    data.radioType = "lte";
                    data.cellTowers.append(_qengExtractServingCellLTE(qengCmdResp.data));
                    // Neighbor towers parameters not correspond google API
                    // +QENG:
                    // "servingcell",<state>,"LTE",<is_tdd>,<mcc>,<mnc>,<cellid>,
                    // <pcid>,<earfcn>,<freq_band_ind>,
                    // <ul_bandwidth>,<d_bandwidth>,<tac>,<rsrp>,<rsrq>,<rssi>,<sinr>,<srxlev>
                    // +QENG: "neighbourcell intra”,"LTE",<earfcn>,<pcid>,<rsrq>,<rsrp>,<rssi>,<sinr>
                    // ,<srxlev>,<cell_resel_priority>,<s_non_intra_search>,<thresh_serving_low>,
                    // <s_intra_search>
                    // https://developers.google.com/maps/documentation/geolocation/overview#cell_tower_object
                    // Location is determined by one tower in this case
                    break;
                default:
                    throw "Unknown radio type: " + srvCellRadioType;
            }
        } catch (err) {
            ::error("Scanning cell towers error: " + err, "BG9xCellInfo");
            return null;
        }

        ::debug("Scanned items: " + data.len(), "BG9xCellInfo");

        return data;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Send the specified AT Command, parse a response.
     * Return table with the parsed response.
     */
    function _writeAndParseAT(cmd) {
        const BG9XCI_FLUSH_TIMEOUT = 2;

        // This helps to avoid "Command in progress" error in some cases
        server.flush(BG9XCI_FLUSH_TIMEOUT);
        local resp = _writeATCommand(cmd);
        return _parseATResp(resp);
    }

    /**
     * Send the specified AT Command, parse a multiline response.
     * Return table with the parsed response.
     */
    function _writeAndParseATMultiline(cmd) {
        local resp = _writeATCommand(cmd);
        return _parseATRespMultiline(resp);
    }

    /**
     * Send the specified AT Command to the modem.
     * Return a string with response.
     *
     * This function uses unofficial impOS feature.
     *
     * This function blocks until the response is returned
     */
    function _writeATCommand(cmd) {
        return imp.setquirk(0x75636feb, cmd);
    }

    /**
     * Parse AT response and looks for "OK", error and response data.
     * Returns table that may contain fields: "raw", "error", "data", "success"
     */
    function _parseATResp(resp) {
        local parsed = {"raw" : resp};

        try {
            parsed.success <- (resp.find("OK") != null);

            local start = resp.find(":");
            (start != null) ? start+=2 : start = 0;

            local newLine = resp.find("\n");
            local end = (newLine != null) ? newLine : resp.len();

            local data = resp.slice(start, end);

            if (resp.find("Error") != null) {
                parsed.error <- data;
            } else {
                parsed.data  <- data;
            }
        } catch(e) {
            parsed.error <- "Error parsing AT response: " + e;
        }

        return parsed;
    }

    /**
     * Parse multiline AT response and looks for "OK", error and response data.
     * Returns table that may contain fields: "raw", "error",
     * "data" (array of string), success.
     */
    function _parseATRespMultiline(resp) {
        local parsed = {"raw" : resp};
        local data = [];
        local lines;

        try {
            parsed.success <- (resp.find("OK") != null);
            lines = split(resp, "\n");

            foreach (line in lines) {
                if (line == "OK") {
                    continue;
                }

                local start = line.find(":");
                (start != null) ? start +=2 : start = 0;

                local dataline = line.slice(start);
                data.push(dataline);

            }

            if (resp.find("Error") != null) {
                parsed.error <- data;
            } else {
                parsed.data  <- data;
            }
        } catch(e) {
            parsed.error <- "Error parsing AT response: " + e;
        }

        return parsed;
    }

    /**
     * Extract mobile country and network codes, location area code,
     * cell ID, signal strength from dataLines parameter.
     * Return the info in array.
     */
    function _qengExtractTowersInfo(dataLines, checkRadioType) {
        try {
            local towers = [];

            foreach (line in dataLines) {
                local splitted = split(line, ",");

                if (splitted.len() < 9) {
                    continue;
                }

                local radioType = splitted[1];
                radioType = split(radioType, "\"")[0];

                if (radioType != checkRadioType) {
                    continue;
                }

                local mcc = splitted[2];
                local mnc = splitted[3];
                local lac = splitted[4];
                local ci = splitted[5];
                local ss = splitted[8];

                lac = utilities.hexStringToInteger(lac);
                ci = utilities.hexStringToInteger(ci);

                towers.append({
                    "mobileCountryCode" : mcc,
                    "mobileNetworkCode" : mnc,
                    "locationAreaCode" : lac,
                    "cellId" : ci,
                    "signalStrength" : ss
                });
            }

            return towers;
        } catch (err) {
            throw "Couldn't parse neighbour cells (GET_QENG cmd): " + err;
        }
    }

    /**
     * Extract radio type from the data parameter.
     * Return the info in a sring.
     */
    function _qengExtractRadioType(data) {
        // +QENG: "servingcell","NOCONN","GSM",250,99,DC51,B919,26,50,-,-73,255,255,0,38,38,1,-,-,-,-,-,-,-,-,-,"-"
        // +QENG: "servingcell","CONNECT","CAT-M","FDD",262,03,2FAA03,187,6200,20,3,3,2AFB,-105,-11,-76,10,-
        try {
            local splitted = split(data, ",");
            local radioType = splitted[2];
            radioType = split(radioType, "\"")[0];

            return radioType;
        } catch (err) {
            throw "Couldn't parse radio type (GET_QENG cmd): " + err;
        }
    }

     /**
     * Extract mobile country and network codes, location area code,
     * cell ID, signal strength from the data parameter. (GSM networks)
     * Return the info in a table.
     */
    function _qengExtractServingCellGSM(data) {
        // +QENG: "servingcell","NOCONN","GSM",250,99,DC51,B919,26,50,-,-73,255,255,0,38,38,1,-,-,-,-,-,-,-,-,-,"-"
        try {
            local splitted = split(data, ",");

            local mcc = splitted[3];
            local mnc = splitted[4];
            local lac = splitted[5];
            local ci = splitted[6];
            local ss = splitted[10];
            lac = utilities.hexStringToInteger(lac);
            ci = utilities.hexStringToInteger(ci);

            return {
                "mobileCountryCode" : mcc,
                "mobileNetworkCode" : mnc,
                "locationAreaCode" : lac,
                "cellId" : ci,
                "signalStrength" : ss
            };
        } catch (err) {
            throw "Couldn't parse serving cell (GET_QENG_SERV_CELL cmd): " + err;
        }
    }

    /**
     * Extract mobile country and network codes, location area code,
     * cell ID, signal strength from the data parameter. (LTE networks)
     * Return the info in a table.
     */
    function _qengExtractServingCellLTE(data) {
        // +QENG: "servingcell","CONNECT","CAT-M","FDD",262,03,2FAA03,187,6200,20,3,3,2AFB,-105,-11,-76,10,-
        try {
            local splitted = split(data, ",");

            local mcc = splitted[4];
            local mnc = splitted[5];
            local tac = splitted[12];
            local ci = splitted[6];
            local ss = splitted[15];
            tac = utilities.hexStringToInteger(tac);
            ci = utilities.hexStringToInteger(ci);

            return {
                "mobileCountryCode" : mcc,
                "mobileNetworkCode" : mnc,
                "locationAreaCode" : tac,
                "cellId" : ci,
                "signalStrength" : ss
            };
        } catch (err) {
            throw "Couldn't parse serving cell (GET_QENG_SERV_CELL cmd): " + err;
        }
    }
}

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


// Enum for BLE scan enable
enum ESP32_BLE_SCAN {
    DISABLE = 0,
    ENABLE = 1
};

// Enum for BLE scan type
enum ESP32_BLE_SCAN_TYPE {
    PASSIVE = 0,
    ACTIVE = 1
};

// Enum for own address type
enum ESP32_BLE_OWN_ADDR_TYPE {
    PUBLIC = 0,
    RANDOM = 1,
    RPA_PUBLIC = 2,
    RPA_RANDOM = 3
};

// Enum for filter policy
enum ESP32_BLE_FILTER_POLICY {
    ALLOW_ALL = 0,
    ALLOW_ONLY_WLST = 1,
    ALLOW_UND_RPA_DIR = 2,
    ALLOW_WLIST_RPA_DIR = 3
};

// Enum for BLE roles
enum ESP32_BLE_ROLE {
    DEINIT = 0,
    CLIENT = 1,
    SERVER = 2
};

// Enum for WiFi modes
enum ESP32_WIFI_MODE {
    DISABLE = 0,
    STATION = 1,
    SOFT_AP = 2,
    SOFT_AP_AND_STATION = 3
};

// Enum for WiFi scan print mask info
enum ESP32_WIFI_SCAN_PRINT_MASK {
    SHOW_ECN = 0x01,
    SHOW_SSID = 0x02,
    SHOW_RSSI = 0x04,
    SHOW_MAC = 0x08,
    SHOW_CHANNEL = 0x10,
    SHOW_FREQ_OFFS = 0x20,
    SHOW_FREQ_VAL = 0x40,
    SHOW_PAIRWISE_CIPHER = 0x80,
    SHOW_GROUP_CIPHER = 0x100,
    SHOW_BGN = 0x200,
    SHOW_WPS = 0x300
};

// Enum for WiFi encryption method
enum ESP32_ECN_METHOD {
    OPEN = 0,
    WEP = 1,
    WPA_PSK = 2,
    WPA2_PSK = 3,
    WPA_WPA2_PSK = 4,
    WPA_ENTERPRISE = 5,
    WPA3_PSK = 6,
    WPA2_WPA3_PSK = 7
};

// Enum for WiFi network parameters order
enum ESP32_WIFI_PARAM_ORDER {
    ECN = 0,
    SSID = 1,
    RSSI = 2,
    MAC = 3,
    CHANNEL = 4
};

// Enum for BLE scan result parameters order
enum ESP32_BLE_PARAM_ORDER {
    ADDR = 0,
    RSSI = 1,
    ADV_DATA = 2,
    SCAN_RSP_DATA = 3,
    ADDR_TYPE = 4
};

// Enum power state
enum ESP32_POWER {
    OFF = 0,
    ON = 1
};

// Internal constants:
// -------------------
// Default baudrate
const ESP32_DEFAULT_BAUDRATE = 115200;
// Default word size
const ESP32_DEFAULT_WORD_SIZE = 8;
// Default parity (PARITY_NONE)
const ESP32_DEFAULT_PARITY = 0;
// Default count on stop bits
const ESP32_DEFAULT_STOP_BITS = 1;
// Default control flags (NO_CTSRTS)
const ESP32_DEFAULT_FLAGS = 4;
// Default RX FIFO size
const ESP32_DEFAULT_RX_FIFO_SZ = 4096;
// Maximum time allowed for waiting for data, in seconds
const ESP32_WAIT_DATA_TIMEOUT = 8;
// Maximum amount of data expected to be received, in bytes
const ESP32_MAX_DATA_LEN = 2048;
// Automatic switch off delay, in seconds
const ESP32_SWITCH_OFF_DELAY = 10;

// Scan interval. It should be more than or equal to the value of <scan_window>.
// The range of this parameter is [0x0004,0x4000].
// The scan interval equals this parameter multiplied by 0.625 ms,
// so the range for the actual scan interval is [2.5,10240] ms.
const ESP32_BLE_SCAN_INTERVAL = 83;
// Scan window. It should be less than or equal to the value of <scan_interval>.
// The range of this parameter is [0x0004,0x4000].
// The scan window equals this parameter multiplied by 0.625 ms,
// so the range for the actual scan window is [2.5,10240] ms.
const ESP32_BLE_SCAN_WINDOW = 83;
// BLE advertisements scan period, in seconds
const ESP32_BLE_SCAN_PERIOD = 6;

// ESP32 Driver class.
// Ability to work with WiFi networks and BLE
class ESP32Driver {
    // Power switch pin
    _switchPin = null;
    // UART object
    _serial = null;
    // All settings
    _settings = null;
    // True if the ESP32 board is switched ON, false otherwise
    _switchedOn = false;
    // True if the ESP32 board is initialized, false otherwise
    _initialized = false;
    // Timer for automatic switch-off of the ESP32 board when idle
    _switchOffTimer = null;

    /**
     * Constructor for ESP32 Driver Class
     *
     * @param {object} switchPin - Hardware pin object connected to load switch
     * @param {object} uart - UART object connected to a ESP32 board
     * @param {table} settings - Connection settings.
     *      Optional, all settings have defaults.
     *      If a setting is missed, it is reset to default.
     *      The settings:
     *          "baudRate"  : {integer} - UART baudrate, in baud per second.
     *                                          Default: ESP32_DEFAULT_BAUDRATE
     *          "wordSize"  : {integer} - Word size, in bits.
     *                                          Default: ESP32_DEFAULT_WORD_SIZE
     *          "parity"    : {integer} - Parity.
     *                                          Default: ESP32_DEFAULT_PARITY
     *          "stopBits"  : {integer} - Count of stop bits.
     *                                          Default: ESP32_DEFAULT_STOP_BITS
     *          "flags"     : {integer} - Control flags.
     *                                          Default: ESP32_DEFAULT_FLAGS
     *          "rxFifoSize": {integer} - The new size of the receive FIFO, in bytes.
     *                                          Default: ESP32_DEFAULT_RX_FIFO_SZ
     */
    constructor(switchPin, uart, settings = {}) {
        _switchPin = switchPin;
        _serial = uart;

        _settings = {
            "baudRate"  : ("baudRate" in settings)   ? settings.baudRate   : ESP32_DEFAULT_BAUDRATE,
            "wordSize"  : ("wordSize" in settings)   ? settings.wordSize   : ESP32_DEFAULT_WORD_SIZE,
            "parity"    : ("parity" in settings)     ? settings.parity     : ESP32_DEFAULT_PARITY,
            "stopBits"  : ("stopBits" in settings)   ? settings.stopBits   : ESP32_DEFAULT_STOP_BITS,
            "flags"     : ("flags" in settings)      ? settings.flags      : ESP32_DEFAULT_FLAGS,
            "rxFifoSize": ("rxFifoSize" in settings) ? settings.rxFifoSize : ESP32_DEFAULT_RX_FIFO_SZ
        };

        // Increase the RX FIFO size to make sure all data from ESP32 will fit into the buffer
        _serial.setrxfifosize(_settings.rxFifoSize);
        // Keep the ESP32 board switched off
        _switchOff();
    }

    /**
     * Scan WiFi networks.
     * NOTE: Parallel requests (2xWiFi or WiFi+BLE scanning) are not allowed
     *
     * @return {Promise} that:
     * - resolves with an array of WiFi networks scanned if the operation succeeded
     *   Each element of the array is a table with the following fields:
     *      "ssid"      : {string}  - SSID (network name).
     *      "bssid"     : {string}  - BSSID (access point’s MAC address), in 0123456789ab format.
     *      "channel"   : {integer} - Channel number: 1-13 (2.4GHz).
     *      "rssi"      : {integer} - RSSI (signal strength).
     *      "open"      : {bool}    - Whether the network is open (password-free).
     * - rejects if the operation failed
     */
    function scanWiFiNetworks() {
        _switchOffTimer && imp.cancelwakeup(_switchOffTimer);

        return _init()
        .then(function(_) {
            ::debug("Scanning WiFi networks..", "ESP32Driver");

            // The string expected to appear in the reply
            local validationString = "\r\nOK\r\n";
            // The tail of the previously received data chunk(s).
            // Needed to make sure we won't miss the validation substring in the
            // reply in case when its parts are in different reply data chunks
            local prevTail = "";

            local streamValidator = function(dataChunk, _) {
                local data = prevTail + dataChunk;
                local tailLen = data.len() - validationString.len();
                prevTail = tailLen > 0 ? data.slice(tailLen) : data;

                return data.find(validationString) != null;
            }.bindenv(this);

            // The result array of parsed WiFi networks
            local wifis = [];
            // The unparsed tail (if any) of the previously received data chunk(s).
            // Needed to make sure we won't lose some results in the reply in case
            // when some parsable units are in different reply data chunks
            local unparsedTail = "";

            local replyStreamHandler = function(dataChunk) {
                unparsedTail = _parseWifiNetworks(unparsedTail + dataChunk, wifis);
                return wifis;
            }.bindenv(this);

            // Send "List Available APs" cmd and parse the result
            return _communicateStream("AT+CWLAP", streamValidator, replyStreamHandler);
        }.bindenv(this))
        .then(function(wifis) {
            ::debug("Scanning of WiFi networks finished successfully. Scanned items: " + wifis.len(), "ESP32Driver");
            _switchOffTimer = imp.wakeup(ESP32_SWITCH_OFF_DELAY, _switchOff.bindenv(this));
            return wifis;
        }.bindenv(this), function(err) {
            _switchOffTimer = imp.wakeup(ESP32_SWITCH_OFF_DELAY, _switchOff.bindenv(this));
            throw err;
        }.bindenv(this));
    }

    /**
     * Scan BLE advertisements.
     * NOTE: Parallel requests (2xBLE or BLE+WiFi scanning) are not allowed
     *
     * @return {Promise} that:
     * - resolves with an array of scanned BLE advertisements if the operation succeeded
     *   Each element of the array is a table with the following fields:
     *     "address"  : {string}  - BLE address.
     *     "rssi"     : {integer} - RSSI (signal strength).
     *     "advData"  : {blob} - Advertising data.
     *     "addrType" : {integer} - Address type: 0 - public, 1 - random.
     * - rejects if the operation failed
     */
    function scanBLEAdverts() {
        _switchOffTimer && imp.cancelwakeup(_switchOffTimer);

        return _init()
        .then(function(_) {
            ::debug("Scanning BLE advertisements..", "ESP32Driver");

            local bleScanCmd = format("AT+BLESCAN=%d,%d", ESP32_BLE_SCAN.ENABLE, ESP32_BLE_SCAN_PERIOD);

            // The string expected to appear in the reply
            local validationString = "\r\nOK\r\n";
            // The tail of the previously received data chunk(s).
            // Needed to make sure we won't miss the validation substring in the
            // reply in case when its parts are in different reply data chunks
            local prevTail = "";
            // True if the validation string has been found
            local stringFound = false;

            local streamValidator = function(dataChunk, timeElapsed) {
                if (!stringFound) {
                    local data = prevTail + dataChunk;
                    stringFound = data.find(validationString) != null;

                    local tailLen = data.len() - validationString.len();
                    prevTail = tailLen > 0 ? data.slice(tailLen) : data;
                }

                return stringFound && timeElapsed >= ESP32_BLE_SCAN_PERIOD;
            }.bindenv(this);

            // The result array of parsed BLE adverts
            local adverts = [];
            // The unparsed tail (if any) of the previously received data chunk(s).
            // Needed to make sure we won't lose some results in the reply in case
            // when some parsable units are in different reply data chunks
            local unparsedTail = "";

            local replyStreamHandler = function(dataChunk) {
                unparsedTail = _parseBLEAdverts(unparsedTail + dataChunk, adverts);
                return adverts;
            }.bindenv(this);

            // Send "Enable Bluetooth LE Scanning" cmd and parse the result
            return _communicateStream(bleScanCmd, streamValidator, replyStreamHandler);
        }.bindenv(this))
        .then(function(adverts) {
            ::debug("Scanning of BLE advertisements finished successfully. Scanned items: " + adverts.len(), "ESP32Driver");
            _switchOffTimer = imp.wakeup(ESP32_SWITCH_OFF_DELAY, _switchOff.bindenv(this));

            // NOTE: It's assumed that MACs are in lower case.
            // Probably, in the future, it's better to explicilty convert them to lower case here
            return adverts;
        }.bindenv(this), function(err) {
            _switchOffTimer = imp.wakeup(ESP32_SWITCH_OFF_DELAY, _switchOff.bindenv(this));
            throw err;
        }.bindenv(this));
    }

    /**
     * Init and configure ESP32.
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function _init() {
        // Delay between powering OFF and ON to restart the ESP32 board, in seconds
        const ESP32_RESTART_DURATION = 1.0;

        if (_initialized) {
            return Promise.resolve(null);
        }

        // Compare BLE scan period and wait data timeout
        if (ESP32_BLE_SCAN_PERIOD > ESP32_WAIT_DATA_TIMEOUT) {
            ::info("BLE scan period is greater than wait data period!", "ESP32Driver");
        }

        ::debug("Starting initialization", "ESP32Driver");

        // Just in case, check if it's already switched ON and switch OFF to start the initialization process from scratch
        if (_switchedOn) {
            _switchOff();
            imp.sleep(ESP32_RESTART_DURATION);
        }

        _switchOn();

        local readyMsgValidator   = @(data, _) data.find("\r\nready\r\n") != null;
        local okValidator         = @(data, _) data.find("\r\nOK\r\n") != null;

        local cmdSetPrintMask = format("AT+CWLAPOPT=0,%d",
                                       ESP32_WIFI_SCAN_PRINT_MASK.SHOW_SSID |
                                       ESP32_WIFI_SCAN_PRINT_MASK.SHOW_MAC |
                                       ESP32_WIFI_SCAN_PRINT_MASK.SHOW_CHANNEL |
                                       ESP32_WIFI_SCAN_PRINT_MASK.SHOW_RSSI |
                                       ESP32_WIFI_SCAN_PRINT_MASK.SHOW_ECN);
        local cmdSetBLEScanParam = format("AT+BLESCANPARAM=%d,%d,%d,%d,%d",
                                          ESP32_BLE_SCAN_TYPE.PASSIVE,
                                          ESP32_BLE_OWN_ADDR_TYPE.PUBLIC,
                                          ESP32_BLE_FILTER_POLICY.ALLOW_ALL,
                                          ESP32_BLE_SCAN_INTERVAL,
                                          ESP32_BLE_SCAN_WINDOW);

        // Functions that return promises which will be executed serially
        local promiseFuncs = [
            // Wait for "ready" message
            _communicate(null, readyMsgValidator),
            // Restore Factory Default Settings
            _communicate("AT+RESTORE", okValidator),
            // Wait for "ready" message once again
            _communicate(null, readyMsgValidator),
            // Check Version Information
            _communicate("AT+GMR", okValidator, _logVersionInfo),
            // Set the Wi-Fi Mode to "Station"
            _communicate(format("AT+CWMODE=%d", ESP32_WIFI_MODE.STATION), okValidator),
            // Set the Configuration for the Command AT+CWLAP (Wi-Fi scanning)
            _communicate(cmdSetPrintMask, okValidator),
            // Initialize the role of BLE
            _communicate(format("AT+BLEINIT=%d", ESP32_BLE_ROLE.CLIENT), okValidator),
            // Set the parameters of Bluetooth LE scanning
            _communicate(cmdSetBLEScanParam, okValidator)
        ];

        return Promise.serial(promiseFuncs)
        .then(function(_) {
            ::debug("Initialization complete", "ESP32Driver");
            _initialized = true;
        }.bindenv(this), function(err) {
            throw "Initialization failure: " + err;
        }.bindenv(this));
    }

    /**
     * Communicate with the ESP32 board: send a command (if passed) and wait for a reply
     *
     * @param {string | null} cmd - String with a command to send or null
     * @param {function} validator - Function that checks if a reply has been fully received
     * @param {function} [replyHandler=null] - Handler that is called to process the reply
     * @param {boolean} [wrapInAFunc=true] - True to wrap the Promise to be returned in an additional function with no params.
     *                                       This option is useful for, e.g., serial execution of a list of promises (Promise.serial)
     *
     * @return {Promise | function}: Promise or a function with no params that returns this promise. The promise:
     * - resolves with the reply (pre-processed if a reply handler specified) if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function _communicate(cmd, validator, replyHandler = null, wrapInAFunc = true) {
        if (wrapInAFunc) {
            return (@() _communicate(cmd, validator, replyHandler, false)).bindenv(this);
        }

        if (cmd) {
            ::debug(format("Sending %s cmd..", cmd), "ESP32Driver");
            _serial.write(cmd + "\r\n");
        }

        return _waitForData(validator)
        .then(function(reply) {
            cmd && ::debug(format("Reply for %s cmd received", cmd), "ESP32Driver");
            return replyHandler ? replyHandler(reply) : reply;
        }.bindenv(this));
    }

    /**
     * Communicate with the ESP32 board: send a command (if passed) and pass the reply as a stream to the handler
     *
     * @param {string | null} cmd - String with a command to send or null
     * @param {function} streamValidator - Function that checks if a reply has been fully received. It's called every time
     *                                     a reply data chunk is received - this chunk (only) is passed to the handler
     * @param {function} replyStreamHandler - Handler that is called to process the reply. It's called every time a reply
     *                                        data chunk is received - this chunk (only) is passed to the handler
     *
     * @return {Promise} that:
     * - resolves with the pre-processed (by the reply handler) reply if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function _communicateStream(cmd, streamValidator, replyStreamHandler) {
        if (cmd) {
            ::debug(format("Sending %s cmd..", cmd), "ESP32Driver");
            _serial.write(cmd + "\r\n");
        }

        local result = null;

        local validator = function(data, timeElapsed) {
            data.len() && (result = replyStreamHandler(data));
            return streamValidator(data, timeElapsed);
        }.bindenv(this);

        return _waitForData(validator, false)
        .then(function(reply) {
            cmd && ::debug(format("Reply for %s cmd received", cmd), "ESP32Driver");
            return result;
        }.bindenv(this));
    }

    /**
     * Switch ON the ESP32 board and configure the UART port
     */
    function _switchOn() {
        _serial.configure(_settings.baudRate,
                          _settings.wordSize,
                          _settings.parity,
                          _settings.stopBits,
                          _settings.flags);
        _switchPin.configure(DIGITAL_OUT, ESP32_POWER.ON);
        _switchedOn = true;

        ::debug("ESP32 board has been switched ON", "ESP32Driver");
    }

    /**
     * Switch OFF the ESP32 board and disable the UART port
     */
    function _switchOff() {
        // NOTE: It's assumed that the module is disabled by default (when the switch pin is tri-stated)
        _switchPin.disable();
        _serial.disable();
        _switchedOn = false;
        _initialized = false;

        ::debug("ESP32 board has been switched OFF", "ESP32Driver");
    }

    /**
     * Parse the data returned by the AT+CWLAP (List Available APs) command
     *
     * @param {string} data - String with a data chunk of the reply to the AT+CWLAP command
     * @param {array} dstArray - Array for saving parsed results
     *  Each element of the array is a table with the following fields:
     *     "ssid"      : {string}  - SSID (network name).
     *     "bssid"     : {string}  - BSSID (access point’s MAC address), in 0123456789ab format.
     *     "channel"   : {integer} - Channel number: 1-13 (2.4GHz).
     *     "rssi"      : {integer} - RSSI (signal strength).
     *     "open"      : {bool}    - Whether the network is open (password-free).
     *
     * @return {string} Unparsed tail of the data chunk or an empty string
     * An exception may be thrown in case of an error.
     */
    function _parseWifiNetworks(data, dstArray) {
        // The data should look like the following:
        // AT+CWLAP
        // +CWLAP:(3,"Ger",-64,"f1:b2:d4:88:16:32",8)
        // +CWLAP:(3,"TP-Link_256",-80,"bb:ae:76:8d:2c:de",10)
        //
        // OK

        // Sub-expressions of the regular expression for parsing AT+CWLAP response
        const ESP32_CWLAP_PREFIX  = @"\+CWLAP:";
        const ESP32_CWLAP_ECN     = @"\d";
        const ESP32_CWLAP_SSID    = @".{0,32}";
        const ESP32_CWLAP_RSSI    = @"-?\d{1,3}";
        const ESP32_CWLAP_MAC     = @"(?:\x\x:){5}\x\x";
        // Only WiFi 2.4GHz (5GHz channels can be 100+)
        const ESP32_CWLAP_CHANNEL = @"\d{1,2}";

        // NOTE: Due to the known issues of regexp (see the electric imp docs), WiFi networks with SSID that contains quotation mark(s) (")
        // will not be recognized by the regular expression and, therefore, will not be in the result list of scanned networks
        local regex = regexp(format(@"^%s\((%s),""(%s)"",(%s),""(%s)"",(%s)\)$",
                                    ESP32_CWLAP_PREFIX,
                                    ESP32_CWLAP_ECN,
                                    ESP32_CWLAP_SSID,
                                    ESP32_CWLAP_RSSI,
                                    ESP32_CWLAP_MAC,
                                    ESP32_CWLAP_CHANNEL));

        ::debug("Parsing the WiFi scan response..", "ESP32Driver");

        try {
            local dataRows = split(data, "\r\n");
            local unparsedTail = "";

            foreach (row in dataRows) {
                local regexCapture = regex.capture(row);

                if (regexCapture == null) {
                    if (row != dataRows.top()) {
                        continue;
                    }

                    local lastChar = data[data.len() - 1];
                    if (lastChar != '\r' && lastChar != '\n') {
                        unparsedTail = row;
                    }

                    break;
                }

                // The first capture is the full row. Let's remove it as we only need the parsed pieces of the row
                regexCapture.remove(0);
                // Convert the array of begin/end indexes to an array of substrings parsed out from the row
                foreach (i, val in regexCapture) {
                    regexCapture[i] = row.slice(val.begin, val.end);
                }

                local scannedWifi = {
                    "ssid"   : regexCapture[ESP32_WIFI_PARAM_ORDER.SSID],
                    "bssid"  : _removeColon(regexCapture[ESP32_WIFI_PARAM_ORDER.MAC]),
                    "channel": regexCapture[ESP32_WIFI_PARAM_ORDER.CHANNEL].tointeger(),
                    "rssi"   : regexCapture[ESP32_WIFI_PARAM_ORDER.RSSI].tointeger(),
                    "open"   : regexCapture[ESP32_WIFI_PARAM_ORDER.ECN].tointeger() == ESP32_ECN_METHOD.OPEN
                };

                dstArray.push(scannedWifi);
            }

            return unparsedTail;
        } catch (err) {
            throw "WiFi networks parsing error: " + err;
        }
    }

    /**
     * Log the data returned by the AT+GMR (Check Version Information) command
     *
     * @param {string} data - String with a reply to the AT+GMR command
     * An exception may be thrown in case of an error.
     */
    function _logVersionInfo(data) {
        // The data should look like the following:
        // AT version:2.2.0.0(c6fa6bf - ESP32 - Jul  2 2021 06:44:05)
        // SDK version:v4.2.2-76-gefa6eca
        // compile time(3a696ba):Jul  2 2021 11:54:43
        // Bin version:2.2.0(WROOM-32)
        //
        // OK

        ::debug("ESP AT software:", "ESP32Driver");

        try {
            local rows = split(data, "\r\n");
            for (local i = 1; i < rows.len() - 1; i++) {
                ::debug(rows[i], "ESP32Driver");
            }
        } catch (err) {
            throw "AT+GMR cmd response parsing error: " + err;
        }
    }

    /**
     * Wait for certain data to be received from the ESP32 board
     *
     * @param {function} validator - Function that gets reply data checks if the expected data has been fully received
     * @param {boolean} [accumulateData=true] - If enabled, reply data will be accumulated across calls of the validator.
     *                                          I.e., all reply data that is already received will be passed to the validator every
     *                                          time it is called. If disabled, only newly received reply data is passed to the validator.
     *                                          This option is useful when a big amount of data is expected to prevent out-of-memory.
     *
     * @return {Promise} that:
     * - resolves with the data received if the operation succeeded
     * - rejects if the operation failed
     */
    function _waitForData(validator, accumulateData = true) {
        // Data check/read period, in seconds
        const ESP32_DATA_CHECK_PERIOD = 0.1;
        // Maximum data length expected to be received from ESP32, in bytes
        const ESP32_DATA_READ_CHUNK_LEN = 1024;

        local start = hardware.millis();
        local data = "";
        local dataLen = 0;

        return Promise(function(resolve, reject) {
            local check;
            check = function() {
                local chunk = _serial.readblob(ESP32_DATA_READ_CHUNK_LEN);
                local chunkLen = chunk.len();

                // Read until FIFO is empty and accumulate to the result string
                while (chunkLen > 0 && data.len() < ESP32_MAX_DATA_LEN) {
                    data += chunk.tostring();
                    dataLen += chunkLen;
                    chunk = _serial.readblob(ESP32_DATA_READ_CHUNK_LEN);
                    chunkLen = chunk.len();
                }

                local timeElapsed = (hardware.millis() - start) / 1000.0;

                if (validator(data, timeElapsed)) {
                    return resolve(data);
                }

                !accumulateData && (data = "");

                if (timeElapsed >= ESP32_WAIT_DATA_TIMEOUT) {
                    return reject("Timeout waiting for the expected data or an acknowledge");
                }

                if (accumulateData && dataLen >= ESP32_MAX_DATA_LEN) {
                    return reject("Too much data received but still no expected data");
                }

                imp.wakeup(ESP32_DATA_CHECK_PERIOD, check);
            }.bindenv(this);

            imp.wakeup(ESP32_DATA_CHECK_PERIOD, check);
        }.bindenv(this));
    }

    /**
     * Remove all colon (:) chars from a string
     *
     * @param {string} str - A string
     *
     * @return {string} String with all colon chars removed
     */
    function _removeColon(str) {
        local subStrings = split(str, ":");
        local res = "";
        foreach (subStr in subStrings) {
            res += subStr;
        }

        return res;
    }

    /**
     * Parse the data returned by the AT+BLESCAN command
     *
     * @param {string} data - String with a data chunk of the reply to the AT+BLESCAN command
     * @param {array} dstArray - Array for saving parsed results. May contain previously saved results
     *  Each element of the array is a table with the following fields:
     *     "address"  : {string}  - BLE address.
     *     "rssi"     : {integer} - RSSI (signal strength).
     *     "advData"  : {blob} - Advertising data.
     *     "addrType" : {integer} - Address type: 0 - public, 1 - random.
     *
     * @return {string} Unparsed tail of the data chunk or an empty string
     * An exception may be thrown in case of an error.
     */
    function _parseBLEAdverts(data, dstArray) {
        // The data should look like the following:
        // AT+BLESCAN=1,5
        // OK
        // +BLESCAN:"6f:92:8a:04:e1:79",-89,1aff4c000215646be3e46e4e4e25ad0177a28f3df4bd00000000bf,,1
        // +BLESCAN:"76:72:c3:3e:29:e4",-79,1bffffffbeac726addafa7044528b00b12f8f57e7d8200000000bb00,,1

        // Sub-expressions of the regular expression for parsing AT+BLESCAN response
        const ESP32_BLESCAN_PREFIX        = @"\+BLESCAN:";
        const ESP32_BLESCAN_ADDR          = @"(?:\x\x:){5}\x\x";
        const ESP32_BLESCAN_RSSI          = @"-?\d{1,3}";
        const ESP32_BLESCAN_ADV_DATA      = @"(?:\x\x){0,31}";
        const ESP32_BLESCAN_SCAN_RSP_DATA = @"(?:\x\x){0,31}";
        const ESP32_BLESCAN_ADDR_TYPE     = @"\d";

        local regex = regexp(format(@"^%s""(%s)"",(%s),(%s),(%s),(%s)$",
                                    ESP32_BLESCAN_PREFIX,
                                    ESP32_BLESCAN_ADDR,
                                    ESP32_BLESCAN_RSSI,
                                    ESP32_BLESCAN_ADV_DATA,
                                    ESP32_BLESCAN_SCAN_RSP_DATA,
                                    ESP32_BLESCAN_ADDR_TYPE));
        ::debug("Parsing the BLE devices scan response..", "ESP32Driver");

        try {
            local dataRows = split(data, "\r\n");
            local unparsedTail = "";

            foreach (row in dataRows) {
                local regexCapture = regex.capture(row);

                if (regexCapture == null) {
                    if (row != dataRows.top()) {
                        continue;
                    }

                    local lastChar = data[data.len() - 1];
                    if (lastChar != '\r' && lastChar != '\n') {
                        unparsedTail = row;
                    }

                    break;
                }

                // The first capture is the full row. Let's remove it as we only need the parsed pieces of the row
                regexCapture.remove(0);
                // Convert the array of begin/end indexes to an array of substrings parsed out from the row
                foreach (i, val in regexCapture) {
                    regexCapture[i] = row.slice(val.begin, val.end);
                }

                local advDataStr = regexCapture[ESP32_BLE_PARAM_ORDER.ADV_DATA];
                local resultAdvert = {
                    "address" : _removeColon(regexCapture[ESP32_BLE_PARAM_ORDER.ADDR]),
                    "rssi"    : regexCapture[ESP32_BLE_PARAM_ORDER.RSSI].tointeger(),
                    "advData" : advDataStr.len() >= 2 ? utilities.hexStringToBlob(advDataStr) : blob(),
                    "addrType": regexCapture[ESP32_BLE_PARAM_ORDER.ADDR_TYPE].tointeger()
                };

                local alreadyExists = false;

                foreach (existingAdvert in dstArray) {
                    if (existingAdvert.address == resultAdvert.address &&
                        existingAdvert.advData.tostring() == resultAdvert.advData.tostring() &&
                        existingAdvert.addrType == resultAdvert.addrType) {
                        alreadyExists = true;
                        existingAdvert.rssi = resultAdvert.rssi;
                        break;
                    }
                }

                if (!alreadyExists) {
                    dstArray.push(resultAdvert);
                }
            }

            return unparsedTail;
        } catch (err) {
            throw "BLE advertisements parsing error: " + err;
        }
    }
}

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


// Default polling period, in seconds
const PR_DEFAULT_POLL_PERIOD = 1.0;
// The value that indicates that the light was detected
const PR_LIGHT_DETECTED_VALUE = 1;

// Photoresistor class.
// Used to poll a photoresistor
class Photoresistor {
    _valPin = null;
    _switchPin = null;
    _pollTimer = null;

    /**
     * Constructor for Photoresistor class
     *
     * @param {object} switchPin - Hardware pin object that switches power of the photoresistor
     * @param {object} valPin - Hardware pin object used for reading the photoresistor's state/value
     */
    constructor(switchPin, valPin) {
        _switchPin = switchPin;
        _valPin = valPin;
    }

    /**
     * Start polling of the photoresistor
     *
     * @param {function} callback - Callback to be called when the state/value on the photoresistor is changed
     * @param {float} [pollPeriod = PR_DEFAULT_POLL_PERIOD] - Polling period
     */
    function startPolling(callback, pollPeriod = PR_DEFAULT_POLL_PERIOD) {
        stopPolling();

        ::debug("Starting polling.. Period = " + pollPeriod, "Photoresistor");

        _switchPin.configure(DIGITAL_OUT, 1);
        _valPin.configure(DIGITAL_IN_WAKEUP);

        local poll;
        local detected = false;

        poll = function() {
            _pollTimer = imp.wakeup(pollPeriod, poll);

            if (detected != (_valPin.read() == PR_LIGHT_DETECTED_VALUE)) {
                detected = !detected;
                ::debug(detected ? "Light has been detected" : "No light detected anymore", "Photoresistor");
                callback(detected);
            }
        }.bindenv(this);

        poll();
    }

    /**
     * Stop polling of the photoresistor
     */
    function stopPolling() {
        _pollTimer && imp.cancelwakeup(_pollTimer);
        _switchPin.disable();
        _valPin.disable();

        ::debug("Polling stopped", "Photoresistor");
    }
}

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


// Accelerometer Driver class:
// - utilizes LIS2DH12 accelerometer connected via I2C
// - detects motion start event
// - detects shock event

// Shock detection:
// ----------------
// see description of the enableShockDetection() method.

// Motion start detection:
// -----------------------
// It is enabled and configured by the detectMotion() method - see its description.
// When enabled, motion start detection consists of two steps:
//   1) Waiting for initial movement detection.
//   2) Confirming the motion during the specified time.
//
// If the motion is confirmed, it is reported and the detection is disabled
// (it should be explicitly re-enabled again, if needed),
// If the motion is not confirmed, return to the step #1 - wait for a movement.
// The movement acceleration threshold is slightly increased in this case
// (between configured min and max values).
// Is reset to the min value once the motion is confirmed.
//
// Motion confirming is based on the two conditions currently:
//   a) If velocity exceeds the specified value and is not zero at the end of the specified time.
//   b) Optional: if distance after the initial movement exceeds the specified value.

// Default I2C address of the connected LIS2DH12 accelerometer
const ACCEL_DEFAULT_I2C_ADDR = 0x32;

// Default Measurement rate - ODR, in Hz
const ACCEL_DEFAULT_DATA_RATE = 100;

// Defaults for shock detection:
// -----------------------------

// Acceleration threshold, in g
const ACCEL_DEFAULT_SHOCK_THR = 8.0; // (for LIS2DH12 register 0x3A)

// Defaults for motion detection:
// ------------------------------

// Duration of exceeding the movement acceleration threshold, in seconds
const ACCEL_DEFAULT_MOV_DUR  = 0.25;
// Movement acceleration maximum threshold, in g
const ACCEL_DEFAULT_MOV_MAX = 0.4;
// Movement acceleration minimum threshold, in g
const ACCEL_DEFAULT_MOV_MIN = 0.2;
// Step change of movement acceleration threshold for bounce filtering, in g
const ACCEL_DEFAULT_MOV_STEP = 0.1;
// Default time to determine motion detection after the initial movement, in seconds.
const ACCEL_DEFAULT_MOTION_TIME = 10.0;
// Default instantaneous velocity to determine motion detection condition, in meters per second.
const ACCEL_DEFAULT_MOTION_VEL = 0.5;
// Default movement distance to determine motion detection condition, in meters.
// If 0, distance is not calculated (not used for motion detection).
const ACCEL_DEFAULT_MOTION_DIST = 0.0;

// Internal constants:
// -------------------
// Acceleration range, in g.
const ACCEL_RANGE = 8;
// Acceleration of gravity (m / s^2)
const ACCEL_G = 9.81;
// Default accelerometer's FIFO watermark
const ACCEL_DEFAULT_WTM = 8;
// Velocity zeroing counter (for stop motion)
const ACCEL_VELOCITY_RESET_CNTR = 4;
// Discrimination window applied low threshold
const ACCEL_DISCR_WNDW_LOW_THR = -0.09;
// Discrimination window applied high threshold
const ACCEL_DISCR_WNDW_HIGH_THR = 0.09;

// States of the motion detection - FSM (finite state machine)
enum ACCEL_MOTION_STATE {
    // Motion detection is disabled (initial state; motion detection is disabled automatically after motion is detected)
    DISABLED = 1,
    // Motion detection is enabled, waiting for initial movement detection
    WAITING = 2,
    // Motion is being confirmed after initial movement is detected
    CONFIRMING = 3
};

const LIS2DH12_CTRL_REG2 = 0x21; // HPF config
const LIS2DH12_REFERENCE = 0x26; // Reference acceleration/tilt value.
const LIS2DH12_HPF_AOI_INT1 = 0x01; // High-pass filter enabled for AOI function on Interrupt 1.
const LIS2DH12_FDS = 0x08; // Filtered data selection. Data from internal filter sent to output register and FIFO.
const LIS2DH12_FIFO_SRC_REG  = 0x2F; // FIFO state register.
const LIS2DH12_FIFO_WTM = 0x80; // Set high when FIFO content exceeds watermark level.
const LIS2DH12_OUT_T_H = 0x0D; // Measured temperature (High byte)
const LIS2DH12_TEMP_EN = 0xC0; // Temperature enable bits (11 - Enable)
const LIS2DH12_BDU = 0x80; // Block Data Update bit (0 - continuous update; default)

// Vector of velocity and movement class.
// Vectors operation in 3D.
class FloatVector {

    // x coordinat
    _x = null;

    // y coordinat
    _y = null;

    // z coordinat
    _z = null;

    /**
     * Constructor for FloatVector Class
     *
     * @param {float} x - Start x coordinat of vector.
     *                       Default: 0.0
     * @param {float} y - Start y coordinat of vector.
     *                       Default: 0.0
     * @param {float} z - Start z coordinat of vector.
     *                       Default: 0.0
     */
    constructor(x = 0.0, y = 0.0, z = 0.0) {
        _x = x;
        _y = y;
        _z = z;
    }

    /**
     * Calculate vector length.
     *
     * @return {float} Current vector length.
     */
    function length() {
        return math.sqrt(_x*_x + _y*_y + _z*_z);
    }

    /**
     * Clear vector (set 0.0 to all coordinates).
     */
    function clear() {
        _x = 0.0;
        _y = 0.0;
        _z = 0.0;
    }

    /**
     * Overload of operation additions for vectors.
     *                                     _ _
     * @return {FloatVector} Result vector X+Y.
     * An exception will be thrown in case of argument is not a FloatVector.
     */
    function _add(val) {
        if (typeof val != "FloatVector") throw "Operand is not a Vector object";
        return FloatVector(_x + val._x, _y + val._y, _z + val._z);
    }

    /**
     * Overload of operation subtractions for vectors.
     *                                     _ _
     * @return {FloatVector} Result vector X-Y.
     * An exception will be thrown in case of argument is not a FloatVector.
     */
    function _sub(val) {
        if (typeof val != "FloatVector") throw "Operand is not a Vector object";
        return FloatVector(_x - val._x, _y - val._y, _z - val._z);
    }

    /**
     * Overload of operation assignment for vectors.
     *
     * @return {FloatVector} Result vector.
     * An exception will be thrown in case of argument is not a FloatVector.
     */
    function _set(val) {
        if (typeof val != "FloatVector") throw "Operand is not a Vector object";
        return FloatVector(val._x, val._y, val._z);
    }

    /**
     * Overload of operation division for vectors.
     *                                             _
     * @return {FloatVector} Result vector (1/alf)*V.
     * An exception will be thrown in case of argument is not a float value.
     */
    function _div(val) {
        if (typeof val != "float") throw "Operand is not a float number";
        return FloatVector(val > 0.0 || val < 0.0 ? _x/val : 0.0,
                           val > 0.0 || val < 0.0 ? _y/val : 0.0,
                           val > 0.0 || val < 0.0 ? _z/val : 0.0);
    }

    /**
     * Overload of operation multiplication for vectors and scalar.
     *                                         _
     * @return {FloatVector} Result vector alf*V.
     * An exception will be thrown in case of argument is not a float value.
     */
    function _mul(val) {
        if (typeof val != "float") throw "Operand is not a float number";
        return FloatVector(_x*val, _y*val, _z*val);
    }

    /**
     * Return type.
     *
     * @return {string} Type name.
     */
    function _typeof() {
        return "FloatVector";
    }

    /**
     * Convert class data to string.
     *
     * @return {string} Class data.
     */
    function _tostring() {
        return (_x + "," + _y + "," + _z);
    }
}

// Accelerometer Driver class.
// Determines the motion and shock detection.
class AccelerometerDriver {
    // enable / disable motion detection
    _enMtnDetect = null;

    // enable / disable shock detection
    _enShockDetect = null;

    // motion detection callback function
    _mtnCb = null;

    // shock detection callback function
    _shockCb = null;

    // pin connected to accelerometer int1 (interrupt check)
    _intPin = null;

    // accelerometer object
    _accel = null;

    // shock threshold value
    _shockThr = null

    // duration of exceeding the movement acceleration threshold
    _movementAccDur = null;

    // current movement acceleration threshold
    _movementCurThr = null;

    // maximum value of acceleration threshold for bounce filtering
    _movementAccMax = null;

    // minimum value of acceleration threshold for bounce filtering
    _movementAccMin = null;

    // maximum time to determine motion detection after the initial movement
    _motionTime = null;

    // timestamp of the movement
    _motionCurTime = null;

    // minimum instantaneous velocity to determine motion detection condition
    _motionVelocity = null;

    // minimal movement distance to determine motion detection condition
    _motionDistance = null;

    // current value of acceleration vector
    _accCur = null;

    // previous value of acceleration vector
    _accPrev = null;

    // current value of velocity vector
    _velCur = null;

    // previous value of velocity vector
    _velPrev = null;

    // current value of position vector
    _positionCur = null;

    // previous value of position vector
    _positionPrev = null;

    // counter for stop motion detection x axis
    _cntrAccLowX = null;

    // counter for stop motion detection y axis
    _cntrAccLowY = null;

    // counter for stop motion detection z axis
    _cntrAccLowZ = null;

    // initial state of motion FSM
    _motionState = null;

    // Flag = true, if minimal velocity for motion detection is exceeded
    _thrVelExceeded = null;

    /**
     * Constructor for Accelerometer Driver Class
     *
     * @param {object} i2c - I2C object connected to accelerometer
     * @param {object} intPin - Hardware pin object connected to accelerometer int1 pin
     * @param {integer} [addr = ACCEL_DEFAULT_I2C_ADDR] - I2C address of accelerometer
     * An exception will be thrown in case of accelerometer configuration error.
     */
    constructor(i2c, intPin, addr = ACCEL_DEFAULT_I2C_ADDR) {
        _enMtnDetect = false;
        _enShockDetect = false;
        _thrVelExceeded = false;
        _shockThr = ACCEL_DEFAULT_SHOCK_THR;
        _movementCurThr = ACCEL_DEFAULT_MOV_MIN;
        _movementAccMin = ACCEL_DEFAULT_MOV_MIN;
        _movementAccMax = ACCEL_DEFAULT_MOV_MAX;
        _movementAccDur = ACCEL_DEFAULT_MOV_DUR;
        _motionCurTime = time();
        _motionVelocity = ACCEL_DEFAULT_MOTION_VEL;
        _motionTime = ACCEL_DEFAULT_MOTION_TIME;
        _motionDistance = ACCEL_DEFAULT_MOTION_DIST;

        _velCur = FloatVector();
        _velPrev = FloatVector();
        _accCur = FloatVector();
        _accPrev = FloatVector();
        _positionCur = FloatVector();
        _positionPrev = FloatVector();

        _cntrAccLowX = ACCEL_VELOCITY_RESET_CNTR;
        _cntrAccLowY = ACCEL_VELOCITY_RESET_CNTR;
        _cntrAccLowZ = ACCEL_VELOCITY_RESET_CNTR;

        _motionState = ACCEL_MOTION_STATE.DISABLED;

        _intPin = intPin;

        try {
            _accel = LIS3DH(i2c, addr);
            _accel.reset();
            local range = _accel.setRange(ACCEL_RANGE);
            ::info(format("Accelerometer range +-%d g", range), "AccelerometerDriver");
            local rate = _accel.setDataRate(ACCEL_DEFAULT_DATA_RATE);
            ::debug(format("Accelerometer rate %d Hz", rate), "AccelerometerDriver");
            _accel.setMode(LIS3DH_MODE_LOW_POWER);
            _accel.enable(true);
            _accel._setReg(LIS2DH12_CTRL_REG2, LIS2DH12_FDS | LIS2DH12_HPF_AOI_INT1);
            _accel._getReg(LIS2DH12_REFERENCE);
            _accel.configureFifo(true, LIS3DH_FIFO_BYPASS_MODE);
            _accel.configureFifo(true, LIS3DH_FIFO_STREAM_TO_FIFO_MODE);
            _accel.getInterruptTable();
            _intPin.configure(DIGITAL_IN_WAKEUP, _checkInt.bindenv(this));
            _accel._getReg(LIS2DH12_REFERENCE);
            ::debug("Accelerometer configured", "AccelerometerDriver");
        } catch (e) {
            throw "Accelerometer configuration error: " + e;
        }
    }

    /**
     * Get temperature value from internal accelerometer thermosensor.
     *
     * @return {float} Temperature value in degrees Celsius.
     */
    function readTemperature() {
        // To convert the raw data to celsius
        const ACCEL_TEMP_TO_CELSIUS = 25.0;
        // Calibration offset for temperature.
        // By default, accelerometer can only provide temperature variaton, not the precise value.
        // NOTE: This value may be inaccurate for some devices. It was chosen based only on two devices
        const ACCEL_TEMP_CALIBRATION_OFFSET = -8.0;
        // Delay to allow the sensor to make a measurement, in seconds
        const ACCEL_TEMP_READING_DELAY = 0.01;

        _switchTempSensor(true);

        imp.sleep(ACCEL_TEMP_READING_DELAY);

        local high = _accel._getReg(LIS2DH12_OUT_T_H);
        local res = (high << 24) >> 24;

        _switchTempSensor(false);

        return res + ACCEL_TEMP_TO_CELSIUS + ACCEL_TEMP_CALIBRATION_OFFSET;
    }

    /**
     * Enables or disables a shock detection.
     * If enabled, the specified callback is called every time the shock condition is detected.
     * @param {function} shockCb - Callback to be called every time the shock condition is detected.
     *        The callback has no parameters. If null or not a function, the shock detection is disabled.
     *        Otherwise, the shock detection is (re-)enabled for the provided shock condition.
     * @param {table} shockCnd - Table with the shock condition settings.
     *        Optional, all settings have defaults.
     *        The settings:
     *          "shockThreshold": {float|integer} - Shock acceleration threshold, in g.
     *                                              Default: ACCEL_DEFAULT_SHOCK_THR
     */
    function enableShockDetection(shockCb, shockCnd = {}) {
        local shockSettIsCorr = true;
        _shockThr = ACCEL_DEFAULT_SHOCK_THR;
        // NOTE: This can be implemented without a loop
        foreach (key, value in shockCnd) {
            if (typeof key == "string") {
                if (key == "shockThreshold") {
                    if (value > 0.0 && value <= 16.0) {
                        _shockThr = value.tofloat();
                    } else {
                        ::error("shockThreshold incorrect value (must be in [0;16] g)", "AccelerometerDriver");
                        shockSettIsCorr = false;
                        break;
                    }
                }
            } else {
                ::error("Incorrect shock condition settings", "AccelerometerDriver");
                shockSettIsCorr = false;
                break;
            }
        }

        if (_isFunction(shockCb) && shockSettIsCorr) {
            _shockCb = shockCb;
            _enShockDetect = true;
            // NOTE: This may need some adjustments depending on the use case
            // Accelerometer range determined by the value of shock threashold
            local range = _accel.setRange(_shockThr.tointeger());
            ::info(format("Accelerometer range +-%d g", range), "AccelerometerDriver");
            // NOTE: Inertial interrupt can be used here instead of click interrupt. It may work better
            _accel.configureClickInterrupt(true, LIS3DH_SINGLE_CLICK, _shockThr);
            ::info("Shock detection enabled", "AccelerometerDriver");
        } else {
            _shockCb = null;
            _enShockDetect = false;
            _accel.configureClickInterrupt(false);
            ::info("Shock detection disabled", "AccelerometerDriver");
        }
    }

    /**
     * Enables or disables a one-time motion detection.
     * If enabled, the specified callback is called only once when the motion condition is detected,
     * after that the detection is automatically disabled and (if needed) should be explicitly re-enabled again.
     * @param {function} motionCb - Callback to be called once when the motion condition is detected.
     *        The callback has no parameters. If null or not a function, the motion detection is disabled.
     *        Otherwise, the motion detection is (re-)enabled for the provided motion condition.
     * @param {table} motionCnd - Table with the motion condition settings.
     *        Optional, all settings have defaults.
     *        The settings:
     *          "movementAccMax": {float|integer} - Movement acceleration maximum threshold, in g.
     *                                              Default: ACCEL_DEFAULT_MOV_MAX
     *          "movementAccMin": {float|integer} - Movement acceleration minimum threshold, in g.
     *                                              Default: ACCEL_DEFAULT_MOV_MIN
     *          "movementAccDur": {float|integer} - Duration of exceeding movement acceleration threshold, in seconds.
     *                                              Default: ACCEL_DEFAULT_MOV_DUR
     *          "motionTime":     {float|integer} - Maximum time to determine motion detection after the initial movement, in seconds.
     *                                              Default: ACCEL_DEFAULT_MOTION_TIME
     *          "motionVelocity": {float|integer} - Minimum instantaneous velocity  to determine motion detection condition, in meters per second.
     *                                              Default: ACCEL_DEFAULT_MOTION_VEL
     *          "motionDistance": {float|integer} - Minimal movement distance to determine motion detection condition, in meters.
     *                                              If 0, distance is not calculated (not used for motion detection).
     *                                              Default: ACCEL_DEFAULT_MOTION_DIST
     */
    function detectMotion(motionCb, motionCnd = {}) {
        local motionSettIsCorr = true;
        _movementCurThr = ACCEL_DEFAULT_MOV_MIN;
        _movementAccMin = ACCEL_DEFAULT_MOV_MIN;
        _movementAccMax = ACCEL_DEFAULT_MOV_MAX;
        _movementAccDur = ACCEL_DEFAULT_MOV_DUR;
        _motionVelocity = ACCEL_DEFAULT_MOTION_VEL;
        _motionTime = ACCEL_DEFAULT_MOTION_TIME;
        _motionDistance = ACCEL_DEFAULT_MOTION_DIST;
        foreach (key, value in motionCnd) {
            if (typeof key == "string") {
                if (key == "movementAccMax") {
                    if (value > 0) {
                        _movementAccMax = value.tofloat();
                    } else {
                        ::error("movementAccMax incorrect value", "AccelerometerDriver");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "movementAccMin") {
                    if (value > 0) {
                        _movementAccMin = value.tofloat();
                        _movementCurThr = value.tofloat();
                    } else {
                        ::error("movementAccMin incorrect value", "AccelerometerDriver");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "movementAccDur") {
                    if (value > 0) {
                        _movementAccDur = value.tofloat();
                    } else {
                        ::error("movementAccDur incorrect value", "AccelerometerDriver");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "motionTime") {
                    if (value > 0) {
                        _motionTime = value.tofloat();
                    } else {
                        ::error("motionTime incorrect value", "AccelerometerDriver");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "motionVelocity") {
                    if (value >= 0) {
                        _motionVelocity = value.tofloat();
                    } else {
                        ::error("motionVelocity incorrect value", "AccelerometerDriver");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "motionDistance") {
                    if (value >= 0) {
                        _motionDistance = value.tofloat();
                    } else {
                        ::error("motionDistance incorrect value", "AccelerometerDriver");
                        motionSettIsCorr = false;
                        break;
                    }
                }
            } else {
                ::error("Incorrect motion condition settings", "AccelerometerDriver");
                motionSettIsCorr = false;
                break;
            }
        }

        if (_isFunction(motionCb) && motionSettIsCorr) {
            _mtnCb = motionCb;
            _enMtnDetect = true;
            _motionState = ACCEL_MOTION_STATE.WAITING;
            _accel.configureFifoInterrupts(false);
            _accel.configureInertialInterrupt(true,
                                              _movementCurThr,
                                              (_movementAccDur*ACCEL_DEFAULT_DATA_RATE).tointeger());
            ::info("Motion detection enabled", "AccelerometerDriver");
        } else {
            _mtnCb = null;
            _enMtnDetect = false;
            _motionState = ACCEL_MOTION_STATE.DISABLED;
            _positionCur.clear();
            _positionPrev.clear();
            _movementCurThr = _movementAccMin;
            _enMtnDetect = false;
            _accel.configureFifoInterrupts(false);
            _accel.configureInertialInterrupt(false);
            ::info("Motion detection disabled", "AccelerometerDriver");
        }
    }

    // ---------------- PRIVATE METHODS ---------------- //

    /**
     * Check object for callback function set method.
     * @param {function} f - Callback function.
     * @return {boolean} true if argument is function and not null.
     */
    function _isFunction(f) {
        return f && typeof f == "function";
    }

    /**
     * Enable/disable internal thermosensor.
     *
     * @param {boolean} enable - true if enable thermosensor.
     */
    function _switchTempSensor(enable) {
        // LIS3DH_TEMP_CFG_REG enables/disables temperature sensor
        _accel._setReg(LIS3DH_TEMP_CFG_REG, enable ? LIS2DH12_TEMP_EN : 0);

        local valReg4 = _accel._getReg(LIS3DH_CTRL_REG4);

        if (enable) {
            valReg4 = valReg4 | LIS2DH12_BDU;
        } else {
            valReg4 = valReg4 & ~LIS2DH12_BDU;
        }

        _accel._setReg(LIS3DH_CTRL_REG4, valReg4);
    }

    /**
     * Handler to check interrupt from accelerometer
     */
    function _checkInt() {
        const ACCEL_SHOCK_COOLDOWN = 1;

        if (_intPin.read() == 0)
            return;

        local intTable = _accel.getInterruptTable();

        if (intTable.singleClick) {
            ::debug("Shock interrupt", "AccelerometerDriver");
            _accel.configureClickInterrupt(false);
            if (_shockCb && _enShockDetect) {
                _shockCb();
            }
            imp.wakeup(ACCEL_SHOCK_COOLDOWN, function() {
                if (_enShockDetect) {
                    _accel.configureClickInterrupt(true, LIS3DH_SINGLE_CLICK, _shockThr);
                }
            }.bindenv(this));
        }

        if (intTable.int1) {
            _accel.configureInertialInterrupt(false);
            _accel.configureFifoInterrupts(true, false, ACCEL_DEFAULT_WTM);
            ledIndication && ledIndication.indicate(LI_EVENT_TYPE.MOVEMENT_DETECTED);
            if (_motionState == ACCEL_MOTION_STATE.WAITING) {
                _motionState = ACCEL_MOTION_STATE.CONFIRMING;
                _motionCurTime = time();
            }
            _accAverage();
            _removeOffset();
            _calcVelosityAndPosition();
            if (_motionState == ACCEL_MOTION_STATE.CONFIRMING) {
                _confirmMotion();
            }
            _checkZeroValueAcc();
        }

        if (_checkFIFOWtrm()) {
            _accAverage();
            _removeOffset();
            _calcVelosityAndPosition();
            if (_motionState == ACCEL_MOTION_STATE.CONFIRMING) {
                _confirmMotion();
            }
            _checkZeroValueAcc();
        }
        _accel.configureFifo(true, LIS3DH_FIFO_BYPASS_MODE);
        _accel.configureFifo(true, LIS3DH_FIFO_STREAM_TO_FIFO_MODE);
    }

    /**
     * Check FIFO watermark.
     * @return {boolean} true if watermark bit is set (for motion).
     */
    function _checkFIFOWtrm() {
        local res = false;
        local fifoSt = 0;
        try {
            fifoSt = _accel._getReg(LIS2DH12_FIFO_SRC_REG);
        } catch (e) {
            ::error("Error get FIFO state register", "AccelerometerDriver");
            fifoSt = 0;
        }

        if (fifoSt & LIS2DH12_FIFO_WTM) {
            res = true;
        }

        return res;
    }

    /**
     * Calculate average acceleration.
     */
    function _accAverage() {
        local stats = _accel.getFifoStats();

        _accCur.clear();

        for (local i = 0; i < stats.unread; i++) {
            local data = _accel.getAccel();

            foreach (key, val in data) {
                if (key == "error") {
                    ::error("Error get acceleration values", "AccelerometerDriver");
                    return;
                }
            }

            local acc = FloatVector(data.x, data.y, data.z);
            _accCur = _accCur + acc;
        }

        if (stats.unread > 0) {
            _accCur = _accCur / stats.unread.tofloat();
        }
    }

    /**
     * Remove offset from acceleration data
     * (Typical zero-g level offset accuracy for LIS2DH 40 mg).
     */
    function _removeOffset() {
        // acceleration |____/\_<- real acceleration______________________ACCEL_DISCR_WNDW_HIGH_THR
        //              |   /  \        /\    /\  <- noise
        //              |--/----\/\----/--\--/--\------------------------- time
        //              |__________\__/____\/_____________________________
        //              |           \/ <- real acceleration               ACCEL_DISCR_WNDW_LOW_THR
        if (_accCur._x < ACCEL_DISCR_WNDW_HIGH_THR && _accCur._x > ACCEL_DISCR_WNDW_LOW_THR) {
            _accCur._x = 0.0;
        }

        if (_accCur._y < ACCEL_DISCR_WNDW_HIGH_THR && _accCur._y > ACCEL_DISCR_WNDW_LOW_THR) {
            _accCur._y = 0.0;
        }

        if (_accCur._z < ACCEL_DISCR_WNDW_HIGH_THR && _accCur._z > ACCEL_DISCR_WNDW_LOW_THR) {
            _accCur._z = 0.0;
        }
    }

    /**
     * Calculate velocity and position.
     */
    function _calcVelosityAndPosition() {
        //  errors of integration are reduced with a first order approximation (Trapezoidal method)
        _velCur = (_accCur + _accPrev) / 2.0;
        // a |  __/|\  half the sum of the bases ((acur + aprev)*0.5) multiplied by the height (dt)
        //   | /|  | \___
        //   |/ |  |   | \
        //   |---------------------------------------- t
        //   |
        //   |   dt
        _velCur = _velCur*(ACCEL_G*ACCEL_DEFAULT_WTM.tofloat() / ACCEL_DEFAULT_DATA_RATE.tofloat());
        _velCur = _velPrev + _velCur;

        if (_motionDistance > 0) {
            _positionCur = (_velCur + _velPrev) / 2.0;
            _positionCur = _positionPrev + _positionCur;
        }
        _accPrev = _accCur;
        _velPrev = _velCur;
        _positionPrev = _positionCur;
    }

    /**
     * Check if motion condition(s) occured
     */
    function _confirmMotion() {
        local vel = _velCur.length();
        local moving = _positionCur.length();

        local diffTm = time() - _motionCurTime;
        if (diffTm < _motionTime) {
            if (vel > _motionVelocity) {
                _thrVelExceeded = true;
            }
            if (_motionDistance > 0 && moving > _motionDistance) {
                _motionConfirmed();
            }
        } else {
            // motion condition: max(V(t)) > Vthr and V(Tmax) > 0 for t -> [0;Tmax]
            if (_thrVelExceeded && vel > 0) {
                _thrVelExceeded = false;
                _motionConfirmed();
                return;
            }
            // if motion not detected increase movement threshold (threshold -> [movMin;movMax])
            _motionState = ACCEL_MOTION_STATE.WAITING;
            _thrVelExceeded = false;
            if (_movementCurThr < _movementAccMax) {
                _movementCurThr += ACCEL_DEFAULT_MOV_STEP;
                if (_movementCurThr > _movementAccMax)
                    _movementCurThr = _movementAccMax;
            }
            ::debug(format("Motion is NOT confirmed. New movementCurThr %f g", _movementCurThr), "AccelerometerDriver")
            _positionCur.clear();
            _positionPrev.clear();
            _accel.configureFifoInterrupts(false);
            _accel.configureInertialInterrupt(true, _movementCurThr, (_movementAccDur*ACCEL_DEFAULT_DATA_RATE).tointeger());
        }
    }

    /**
     * Motion callback function execute and disable interrupts.
     */
    function _motionConfirmed() {
        ::info("Motion confirmed", "AccelerometerDriver");
        _motionState = ACCEL_MOTION_STATE.DISABLED;
        if (_mtnCb && _enMtnDetect) {
            // clear current and previous position for new motion detection
            _positionCur.clear();
            _positionPrev.clear();
            // reset movement threshold to minimum value
            _movementCurThr = _movementAccMin;
            _enMtnDetect = false;
            // disable all interrupts
            _accel.configureInertialInterrupt(false);
            _accel.configureFifoInterrupts(false);
            ::debug("Motion detection disabled", "AccelerometerDriver");
            _mtnCb();
        }
    }

    /**
     * Сheck for zero acceleration.
     */
    function _checkZeroValueAcc() {
        if (_accCur._x == 0.0) {
            if (_cntrAccLowX > 0)
                _cntrAccLowX--;
            else if (_cntrAccLowX == 0) {
                _cntrAccLowX = ACCEL_VELOCITY_RESET_CNTR;
                _velCur._x = 0.0;
                _velPrev._x = 0.0;
            }
        }

        if (_accCur._y == 0.0) {
            if (_cntrAccLowY > 0)
                _cntrAccLowY--;
            else if (_cntrAccLowY == 0) {
                _cntrAccLowY = ACCEL_VELOCITY_RESET_CNTR;
                _velCur._y = 0.0;
                _velPrev._y = 0.0;
            }
        }

        if (_accCur._z == 0.0) {
            if (_cntrAccLowZ > 0)
                _cntrAccLowZ--;
            else if (_cntrAccLowZ == 0) {
                _cntrAccLowZ = ACCEL_VELOCITY_RESET_CNTR;
                _velCur._z = 0.0;
                _velPrev._z = 0.0;
            }
        }
    }
}

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


// Delay (sec) between reads when getting the average value
const BM_AVG_DELAY = 0.8;
// Number of reads for getting the average value
const BM_AVG_SAMPLES = 6;
// Voltage gain according to the voltage divider
const BM_VOLTAGE_GAIN = 2.4242;

// 3 x 1.5v battery
const BM_FULL_VOLTAGE = 4.2;

// Battery class:
// - Reads battery voltage (several times with a delay)
// - Converts it to remaining capacity (%)
class BatteryMonitor {
    _batLvlEnablePin = null;
    _batLvlPin = null;
    _measuringBattery = null;

    // Voltage (normalized to 0-1 range) -> remaining capacity (normalized to 0-1 range)
    // Must be sorted by descending of Voltage
    _calibrationTable = [
        [1.0,     1.0],
        [0.975,   0.634],
        [0.97357, 0.5405],
        [0.94357, 0.44395],
        [0.94214, 0.37677],
        [0.90143, 0.21877],
        [0.86786, 0.13403],
        [0.82571, 0.06954],
        [0.79857, 0.04018],
        [0.755,   0.01991],
        [0.66071, 0.00236],
        [0.0,     0.0]
    ];

    /**
     * Constructor for Battery Monitor class
     *
     * @param {object} batLvlEnablePin - Hardware pin object that enables battery level measurement circuit
     * @param {object} batLvlPin - Hardware pin object that measures battery level (voltage)
     */
    constructor(batLvlEnablePin, batLvlPin) {
        _batLvlEnablePin = batLvlEnablePin;
        _batLvlPin = batLvlPin;
    }

    /**
     * Measure battery level
     *
     * @return {Promise} that resolves with the result of the battery measuring.
     *  The result is a table { "percent": <pct>, "voltage": <V> }
     */
    function measureBattery() {
        if (_measuringBattery) {
            return _measuringBattery;
        }

        _batLvlEnablePin.configure(DIGITAL_OUT, 1);
        _batLvlPin.configure(ANALOG_IN);

        return _measuringBattery = Promise(function(resolve, reject) {
            local measures = 0;
            local sumVoltage = 0;

            local measure = null;
            measure = function() {
                // Sum voltage to get the average value
                // Vbat = PinVal / 65535 * hardware.voltage() * (220k + 180k) / 180k
                sumVoltage += (_batLvlPin.read() / 65535.0) * hardware.voltage();
                measures++;

                if (measures < BM_AVG_SAMPLES) {
                    imp.wakeup(BM_AVG_DELAY, measure);
                } else {
                    _batLvlEnablePin.disable();
                    _batLvlPin.disable();
                    _measuringBattery = null;

                    // There is a voltage divider
                    local avgVoltage = sumVoltage * BM_VOLTAGE_GAIN / BM_AVG_SAMPLES;

                    local level = _getBatteryLevelByVoltage(avgVoltage);
                    ::debug("Battery level (raw):", "BatteryMonitor");
                    ::debug(level, "BatteryMonitor");

                    // Sampling complete, return result
                    resolve(level);
                }
            }.bindenv(this);

            measure();
        }.bindenv(this));
    }

    function _getBatteryLevelByVoltage(voltage) {
        local calTableLen = _calibrationTable.len();

        for (local i = 0; i < calTableLen; i++) {
            local point = _calibrationTable[i];
            local calVoltage = point[0] * BM_FULL_VOLTAGE;
            local calPercent = point[1] * 100.0;

            if (voltage < calVoltage) {
                continue;
            }

            if (i == 0) {
                return { "percent": 100.0, "voltage": voltage };
            }

            local prevPoint = _calibrationTable[i - 1];
            local prevCalVoltage = prevPoint[0] * BM_FULL_VOLTAGE;
            local prevCalPercent = prevPoint[1] * 100.0;

            // Calculate linear (y = k*x + b) coefficients, where x is Voltage and y is Percent
            local k = (calPercent - prevCalPercent) / (calVoltage - prevCalVoltage);
            local b = calPercent - k * calVoltage;

            local percent = k * voltage + b;

            return { "percent": percent, "voltage": voltage };
        }

        return { "percent": 0.0, "voltage": voltage };
    }
}

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


// Mean earth radius in meters (https://en.wikipedia.org/wiki/Great-circle_distance)
const MM_EARTH_RAD = 6371009;

// Motion Monitor class.
// Starts and stops motion monitoring.
class LocationMonitor {
    // Location driver object
    _ld = null;

    // Location callback function
    _locationCb = null;

    // Location reading timer period
    _locReadingPeriod = null;

    // Location reading timer
    _locReadingTimer = null;

    // Promise of the location reading process or null
    _locReadingPromise = null;

    // If true, activate unconditional periodic location reading
    _alwaysReadLocation = false;

    // Geofence settings, state, callback(s), timer(s) and etc.
    _geofence = null;

    // Repossession mode settings, state, callback(s), timer(s) and etc.
    _repossession = null;

    /**
     *  Constructor for Motion Monitor class.
     *  @param {object} locDriver - Location driver object.
     */
    constructor(locDriver) {
        _ld = locDriver;

        // This table will be augmented by several fields from the configuration: "enabled" and "after"
        _repossession = {
            // A flag indicating if the repossession mode is activated
            "activated": false,
            // A timer to activate the repossession mode after the time specified in the configuration
            "timer": null,
            // Repossession event callback function
            "eventCb": null
        };

        // This table will be augmented by several fields from the configuration: "enabled", "lng", "lat" and "radius"
        _geofence = {
            // Geofencing state: true (in zone) / false (out of zone) / null (unknown)
            "inZone": null,
            // Geofencing event callback function
            "eventCb": null
        };
    }

    /**
     *  Start motion monitoring
     *
     *  @param {table} cfg - Table with the full configuration.
     *                       For details, please, see the documentation
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function start(cfg) {
        updateCfg(cfg);

        // get current location
        _readLocation();

        return Promise.resolve(null);
    }

    /**
     * Update configuration
     *
     * @param {table} cfg - Configuration. May be partial.
     *                      For details, please, see the documentation
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function updateCfg(cfg) {
        // First configure BLE devices because next lines will likely start location obtaining
        _updCfgBLEDevices(cfg);
        _updCfgGeneral(cfg);
        _updCfgGeofence(cfg);
        _updCfgRepossession(cfg);

        return Promise.resolve(null);
    }

    /**
     * Get status info
     *
     * @return {table} with the following keys and values:
     *  - "flags": a table with keys "inGeofence" and "repossession"
     *  - "location": the last known (if any) or "default" location
     *  - "gnssInfo": extra GNSS info from LocationDriver
     */
    function getStatus() {
        local location = _ld.lastKnownLocation() || {
            "timestamp": 0,
            "type": "gnss",
            "accuracy": MM_EARTH_RAD,
            "longitude": INIT_LONGITUDE,
            "latitude": INIT_LATITUDE
        };

        local res = {
            "flags": {},
            "location": location,
            "gnssInfo": _ld.getExtraInfo().gnss
        };

        (_geofence.inZone != null) && (res.flags.inGeofence <- _geofence.inZone);
        _repossession.enabled && (res.flags.repossession <- _repossession.activated);

        return res;
    }

    /**
     * Set or unset a callback to be called when location obtaining is finished (successfully or not)
     *
     * @param {function | null} locationCb - Location callback. Or null to unset the callback
     */
    function setLocationCb(locationCb) {
        _locationCb = locationCb;
        // This will either:
        // - Run periodic location reading (if a callback has just been set) OR
        // - Cancel the timer for periodic location reading (if the callback has just been
        //   unset and the other conditions don't require to read the location periodically)
        _managePeriodicLocReading(true);
    }

    /**
     * Set a callback to be called when repossession mode is activated
     *
     * @param {function} repossessionEventCb - Callback function
     */
    function setRepossessionEventCb(repossessionEventCb) {
        _repossession.eventCb = repossessionEventCb;
    }

    /**
     *  Set geofencing event callback function
     *
     *  @param {function | null} geofencingEventCb - The callback will be called every time the new
     *                                               geofencing event is detected (null - disables the callback)
     *                           geofencingEventCb(ev), where
     *                               @param {bool} ev - true: geofence entered, false: geofence exited
     */
    function setGeofencingEventCb(geofencingEventCb) {
        _geofence.eventCb = geofencingEventCb;
    }

    /**
     *  Calculate distance between two locations
     *
     *   @param {table} locationFirstPoint - Table with the first location value.
     *        The table must include parts:
     *          "longitude": {float} - Longitude, in degrees.
     *          "latitude":  {float} - Latitude, in degrees.
     *   @param {table} locationSecondPoint - Table with the second location value.
     *        The location must include parts:
     *          "longitude": {float} - Longitude, in degrees.
     *          "latitude":  {float} - Latitude, in degrees.
     *
     *   @return {float} If success - value, else - default value (0).
     */
    function greatCircleDistance(locationFirstPoint, locationSecondPoint) {
        local dist = 0;

        if (locationFirstPoint != null || locationSecondPoint != null) {
            if ("longitude" in locationFirstPoint &&
                "longitude" in locationSecondPoint &&
                "latitude" in locationFirstPoint &&
                "latitude" in locationSecondPoint) {
                // https://en.wikipedia.org/wiki/Great-circle_distance
                local deltaLat = math.fabs(locationFirstPoint.latitude -
                                           locationSecondPoint.latitude)*PI/180.0;
                local deltaLong = math.fabs(locationFirstPoint.longitude -
                                            locationSecondPoint.longitude)*PI/180.0;
                //  -180___180
                //     / | \
                //west|  |  |east   selection of the shortest arc
                //     \_|_/
                // Earth 0 longitude
                if (deltaLong > PI) {
                    deltaLong = 2*PI - deltaLong;
                }
                local deltaSigma = math.pow(math.sin(0.5*deltaLat), 2);
                deltaSigma += math.cos(locationFirstPoint.latitude*PI/180.0)*
                              math.cos(locationSecondPoint.latitude*PI/180.0)*
                              math.pow(math.sin(0.5*deltaLong), 2);
                deltaSigma = 2*math.asin(math.sqrt(deltaSigma));

                // actual arc length on a sphere of radius r (mean Earth radius)
                dist = MM_EARTH_RAD*deltaSigma;
            }
        }

        return dist;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    function _updCfgGeneral(cfg) {
        local readingPeriod = getValFromTable(cfg, "locationTracking/locReadingPeriod");
        _alwaysReadLocation = getValFromTable(cfg, "locationTracking/alwaysOn", _alwaysReadLocation);
        _locReadingPeriod = readingPeriod != null ? readingPeriod : _locReadingPeriod;

        // This will either:
        // - Run periodic location reading (if it's not running but the new settings require
        //   this or if the reading period has been changed) OR
        // - Cancel the timer for periodic location reading (if the new settings and the other conditions don't require this) OR
        // - Do nothing (if periodic location reading is already running
        //   (and still should be) and the reading period hasn't been changed)
        _managePeriodicLocReading(readingPeriod != null);
    }

    function _updCfgBLEDevices(cfg) {
        local bleDevicesCfg = getValFromTable(cfg, "locationTracking/bleDevices");
        local enabled = getValFromTable(bleDevicesCfg, "enabled");
        local knownBLEDevices = nullEmpty(getValsFromTable(bleDevicesCfg, ["generic", "iBeacon"]));

        _ld.configureBLEDevices(enabled, knownBLEDevices);
    }

    function _updCfgGeofence(cfg) {
        // There can be the following fields: "enabled", "lng", "lat" and "radius"
        local geofenceCfg = getValFromTable(cfg, "locationTracking/geofence");

        // If there is some change, let's reset _geofence.inZone as we now don't know if we are in the zone
        if (geofenceCfg) {
            _geofence.inZone = null;
        }

        _geofence = mixTables(geofenceCfg, _geofence);
    }

    function _updCfgRepossession(cfg) {
        // There can be the following fields: "enabled" and "after"
        local repossessionCfg = getValFromTable(cfg, "locationTracking/repossessionMode");

        if (repossessionCfg) {
            // repossessionCfg is not null - this means, we have some updates in parameters
            mixTables(repossessionCfg, _repossession);

            // Let's deactivate everything since the settings changed
            _repossession.activated = false;
            _repossession.timer && imp.cancelwakeup(_repossession.timer);

            // And re-activate again if needed
            if (_repossession.enabled) {
                ::debug("Enabling repossession mode..", "LocationMonitor");

                local activateRepossession = function() {
                    ::debug("Repossession mode activated!", "LocationMonitor");

                    _repossession.activated = true;
                    _repossession.eventCb && _repossession.eventCb();
                    _readLocation();
                }.bindenv(this);

                // If "after" is less than the current time, this timer will fire immediately
                _repossession.timer = imp.wakeup(_repossession.after - time(), activateRepossession);
            }

            // This will either:
            // - Cancel the timer for periodic location reading (if the new settings and the other conditions don't require this) OR
            // - Do nothing (if periodic location reading is already running and still should be)
            _managePeriodicLocReading();
        }
    }

    function _managePeriodicLocReading(reset = false) {
        if (_shouldReadPeriodically()) {
            // If the location reading timer is not currently set or if we should "reset" the periodic location reading,
            // let's call _readLocation right now. This will cancel the existing timer (if any) and request the location
            // (if it's not being obtained right now)
            (!_locReadingTimer || reset) && _readLocation();
        } else {
            _locReadingTimer && imp.cancelwakeup(_locReadingTimer);
            _locReadingTimer = null;
        }
    }

    function _shouldReadPeriodically() {
        return _alwaysReadLocation || _locationCb || _repossession.activated;
    }

    /**
     *  Try to determine the current location
     */
    function _readLocation() {
        if (_locReadingPromise) {
            return;
        }

        local start = hardware.millis();

        _locReadingTimer && imp.cancelwakeup(_locReadingTimer);
        _locReadingTimer = null;

        ::debug("Getting location..", "LocationMonitor");

        _locReadingPromise = _ld.getLocation()
        .then(function(loc) {
            _locationCb && _locationCb(loc);
            _procGeofence(loc);
        }.bindenv(this), function(_) {
            _locationCb && _locationCb(null);
        }.bindenv(this))
        .finally(function(_) {
            _locReadingPromise = null;

            if (_shouldReadPeriodically()) {
                // Calculate the delay for the timer according to the time spent on location reading
                local delay = _locReadingPeriod - (hardware.millis() - start) / 1000.0;
                ::debug(format("Setting the timer for location reading in %d sec", delay), "LocationMonitor");
                _locReadingTimer = imp.wakeup(delay, _readLocation.bindenv(this));
            }
        }.bindenv(this));
    }

    /**
     *  Zone border crossing check
     *
     *   @param {table} curLocation - Table with the current location.
     *        The table must include parts:
     *          "accuracy" : {integer}  - Accuracy, in meters.
     *          "longitude": {float}    - Longitude, in degrees.
     *          "latitude" : {float}    - Latitude, in degrees.
     */
    function _procGeofence(curLocation) {
        //              _____GeofenceZone
        //             /      \
        //            /__     R\    dist           __Location
        //           |/\ \  .---|-----------------/- \
        //           |\__/      |                 \_\/accuracy (radius)
        //            \ Location/
        //             \______ /
        //            in zone                     not in zone
        // (location with accuracy radius      (location with accuracy radius
        //  entirely in geofence zone)          entirely not in geofence zone)
        if (_geofence.enabled) {
            local center = { "latitude": _geofence.lat, "longitude": _geofence.lng };
            local dist = greatCircleDistance(center, curLocation);
            ::debug("Geofence distance: " + dist, "LocationMonitor");
            if (dist > _geofence.radius) {
                local distWithoutAccurace = dist - curLocation.accuracy;
                if (distWithoutAccurace > 0 && distWithoutAccurace > _geofence.radius) {
                    if (_geofence.inZone != false) {
                        _geofence.inZone = false;
                        _geofence.eventCb && _geofence.eventCb(false);
                    }
                }
            } else {
                local distWithAccurace = dist + curLocation.accuracy;
                if (distWithAccurace <= _geofence.radius) {
                    if (_geofence.inZone != true) {
                        _geofence.inZone = true;
                        _geofence.eventCb && _geofence.eventCb(true);
                    }
                }
            }
        }
    }
}

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


// Mean earth radius in meters (https://en.wikipedia.org/wiki/Great-circle_distance)
const MM_EARTH_RAD = 6371009;

// Motion Monitor class.
// Implements an algorithm of motion monitoring based on accelerometer and location
class MotionMonitor {
    // Accelerometer driver object
    _ad = null;

    // Location Monitor object
    _lm = null;

    // Motion event callback function
    _motionEventCb = null;

    // Motion stop assumption
    _motionStopAssumption = false;

    // Motion state: true (in motion) / false (not in motion) / null (feature disabled)
    _inMotion = null;

    // Current location
    _curLoc = null;

    // Sign of the current location relevance
    // True (relevant) / false (not relevant) / null (haven't yet got a location or a failure)
    _curLocFresh = null;

    // Previous location
    _prevLoc = null;

    // Sign of the previous location relevance
    // True (relevant) / false (not relevant) / null (haven't yet got a location or a failure)
    _prevLocFresh = null;

    // Motion stop confirmation timeout
    _motionStopTimeout = null;

    // Motion stop confirmation timer
    _confirmMotionStopTimer = null;

    // Motion monitoring state: enabled/disabled
    _motionMonitoringEnabled = false;

    // Accelerometer's parameters for motion detection
    _accelDetectMotionParams = null;

    /**
     *  Constructor for Motion Monitor class.
     *  @param {object} accelDriver - Accelerometer driver object.
     *  @param {object} locMonitor - Location Monitor object.
     */
    constructor(accelDriver, locMonitor) {
        _ad = accelDriver;
        _lm = locMonitor;
    }

    /**
     *  Start motion monitoring
     *
     *  @param {table} cfg - Table with the full configuration.
     *                       For details, please, see the documentation
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function start(cfg) {
        _curLoc = _lm.getStatus().location;
        _prevLoc = clone _curLoc;

        return updateCfg(cfg);
    }

    /**
     * Update configuration
     *
     * @param {table} cfg - Configuration. May be partial.
     *                      For details, please, see the documentation
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function updateCfg(cfg) {
        local detectMotionParamNames = ["movementAccMin", "movementAccMax", "movementAccDur",
                                        "motionTime", "motionVelocity", "motionDistance"];

        local motionMonitoringCfg = getValFromTable(cfg, "locationTracking/motionMonitoring");
        local newDetectMotionParams = nullEmpty(getValsFromTable(motionMonitoringCfg, detectMotionParamNames));
        // Can be: true/false/null
        local enabledParam = getValFromTable(motionMonitoringCfg, "enabled");

        _accelDetectMotionParams = mixTables(newDetectMotionParams, _accelDetectMotionParams || {});
        _motionStopTimeout = getValFromTable(motionMonitoringCfg, "motionStopTimeout", _motionStopTimeout);

        local enable   = !_motionMonitoringEnabled && enabledParam == true;
        local reEnable =  _motionMonitoringEnabled && enabledParam != false && newDetectMotionParams;
        local disable  =  _motionMonitoringEnabled && enabledParam == false;

        if (reEnable || enable) {
            ::debug("(Re)enabling motion monitoring..", "MotionMonitor");

            _inMotion = false;
            _motionStopAssumption = false;
            _motionMonitoringEnabled = true;

            // Enable (or re-enable) motion detection
            _ad.detectMotion(_onAccelMotionDetected.bindenv(this), _accelDetectMotionParams);
        } else if (disable) {
            ::debug("Disabling motion monitoring..", "MotionMonitor");

            _inMotion = null;
            _motionStopAssumption = false;
            _motionMonitoringEnabled = false;

            // Disable motion detection
            _ad.detectMotion(null);
            // Cancel the timer as we don't check for motion anymore
            _confirmMotionStopTimer && imp.cancelwakeup(_confirmMotionStopTimer);
        }

        return Promise.resolve(null);
    }

    /**
     * Get status info
     *
     * @return {table} with the following keys and values:
     *  - "flags": a table with key "inMotion"
     */
    function getStatus() {
        local res = {
            "flags": {}
        };

        (_inMotion != null) && (res.flags.inMotion <- _inMotion);

        return res;
    }

    /**
     *  Set motion event callback function.
     *  @param {function | null} motionEventCb - The callback will be called every time the new motion event is detected (null - disables the callback)
     *                 motionEventCb(ev), where
     *                 @param {bool} ev - true: motion started, false: motion stopped
     */
    function setMotionEventCb(motionEventCb) {
        _motionEventCb = motionEventCb;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     *  Motion stop confirmation timer callback function
     */
    function _confirmMotionStop() {
        if (_motionStopAssumption) {
            // No movement during motion stop confirmation period => motion stop is confirmed
            _inMotion = false;
            _motionStopAssumption = false;
            _motionEventCb && _motionEventCb(false);

            // Clear these variables so that next time we need to get the location, at least,
            // two times before checking if the motion is stopped
            _curLocFresh = _prevLocFresh = null;
        } else {
            // Since we are still in motion, we need to get new locations
            _lm.setLocationCb(_onLocation.bindenv(this));
        }
    }

    /**
     * A callback called when location obtaining is finished (successfully or not)
     *
     * @param {table | null} location - The location obtained or null
     */
    function _onLocation(location) {
        _prevLoc = _curLoc;
        _prevLocFresh = _curLocFresh;

        if (location) {
            _curLoc = location;
            _curLocFresh = true;
        } else {
            // the current location becomes non-fresh
            _curLocFresh = false;
        }

        // Once we have got two locations or failures, let's check if the motion stopped
        (_prevLocFresh != null) && _checkMotionStop();
    }

    /**
     *  Check if the motion is stopped
     */
    function _checkMotionStop() {
        if (_curLocFresh) {
            // Calculate distance between two locations
            local dist = _lm.greatCircleDistance(_curLoc, _prevLoc);

            ::debug("Distance: " + dist, "MotionMonitor");

            // Check if the distance is less than 2 radius of accuracy.
            // Maybe motion is stopped but need to double check
            _motionStopAssumption = dist < 2*_curLoc.accuracy;
        } else if (!_prevLocFresh) {
            // The location has not been determined two times in a row,
            // need to double check the motion
            _motionStopAssumption = true;
        }

        if (_motionStopAssumption) {
            // We don't need new locations anymore
            _lm.setLocationCb(null);
            // Enable motion detection by accelerometer to double check the motion
            _ad.detectMotion(_onAccelMotionDetected.bindenv(this), _accelDetectMotionParams);
            // Set a timer for motion stop confirmation timeout
            _confirmMotionStopTimer = imp.wakeup(_motionStopTimeout, _confirmMotionStop.bindenv(this));
        }
    }

    /**
     *  The handler is called when the motion is detected by accelerometer
     */
    function _onAccelMotionDetected() {
        _motionStopAssumption = false;
        if (!_inMotion) {
            _inMotion = true;

            // Start getting new locations to check if we are actually moving
            _lm.setLocationCb(_onLocation.bindenv(this));
            _motionEventCb && _motionEventCb(true);
        }
    }
}

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


// Temperature state enum
enum DP_TEMPERATURE_LEVEL {
    LOW,
    NORMAL,
    HIGH
};

// Battery voltage state enum
enum DP_BATTERY_LEVEL {
    NORMAL,
    LOW
};

// Battery level hysteresis
const DP_BATTERY_LEVEL_HYST = 4.0;

// Data Processor class.
// Processes data, saves and sends messages
class DataProcessor {
    // Data reading timer period
    _dataReadingPeriod = null;

    // Data reading timer handler
    _dataReadingTimer = null;

    // Data reading Promise (null if no data reading is ongoing)
    _dataReadingPromise = null;

    // Data sending timer period
    _dataSendingPeriod = null;

    // Data sending timer handler
    _dataSendingTimer = null;

    // Battery driver object
    _bd = null;

    // Accelerometer driver object
    _ad = null;

    // Location Monitor object
    _lm = null;

    // Motion Monitor driver object
    _mm = null;

    // Photoresistor object
    _pr = null;

    // Last temperature value
    _temperature = null;

    // Last battery level
    _batteryLevel = null;

    // Array of alerts
    _allAlerts = null;

    // state battery (voltage in permissible range or not)
    _batteryState = DP_BATTERY_LEVEL.NORMAL;

    // temperature state (temperature in permissible range or not)
    _temperatureState = DP_TEMPERATURE_LEVEL.NORMAL;

    // Settings of shock, temperature and battery alerts
    _alertsSettings = null;

    // Cellular info Promise (null if it's not in progress)
    _cellInfoPromise = null;

    // Last obtained cellular info. Cleared once sent
    _lastCellInfo = null;

    // Last obtained GNSS info
    _lastGnssInfo = null;

    /**
     *  Constructor for Data Processor class.
     *  @param {object} locationMon - Location monitor object.
     *  @param {object} motionMon - Motion monitor object.
     *  @param {object} accelDriver - Accelerometer driver object.
     *  @param {object} batDriver - Battery driver object.
     *  @param {object} photoresistor - Photoresistor object.
     */
    constructor(locationMon, motionMon, accelDriver, batDriver, photoresistor) {
        _ad = accelDriver;
        _lm = locationMon;
        _mm = motionMon;
        _bd = batDriver;
        _pr = photoresistor;

        _allAlerts = {
            "shockDetected"         : false,
            "motionStarted"         : false,
            "motionStopped"         : false,
            "geofenceEntered"       : false,
            "geofenceExited"        : false,
            "repossessionActivated" : false,
            "temperatureHigh"       : false,
            "temperatureLow"        : false,
            "batteryLow"            : false,
            "tamperingDetected"     : false
        };

        _alertsSettings = {
            "shockDetected"     : {},
            "temperatureHigh"   : {},
            "temperatureLow"    : {},
            "batteryLow"        : {},
            "tamperingDetected" : {}
        };
    }

    /**
     *  Start data processing
     *
     *  @param {table} cfg - Table with the full configuration.
     *                       For details, please, see the documentation
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function start(cfg) {
        cm.onConnect(_getCellInfo.bindenv(this), "DataProcessor");

        updateCfg(cfg);

        _lm.setGeofencingEventCb(_onGeofencingEvent.bindenv(this));
        _lm.setRepossessionEventCb(_onRepossessionEvent.bindenv(this));
        _mm.setMotionEventCb(_onMotionEvent.bindenv(this));

        return Promise.resolve(null);
    }

    /**
     * Update configuration
     *
     * @param {table} cfg - Configuration. May be partial
     *                      For details, please, see the documentation
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function updateCfg(cfg) {
        _updCfgAlerts(cfg);
        // This call will trigger data reading/sending. So it should be the last one
        _updCfgGeneral(cfg);

        return Promise.resolve(null);
    }

    // -------------------- PRIVATE METHODS -------------------- //

    function _updCfgGeneral(cfg) {
        if ("readingPeriod" in cfg || "connectingPeriod" in cfg) {
            _dataReadingPeriod = getValFromTable(cfg, "readingPeriod", _dataReadingPeriod);
            _dataSendingPeriod = getValFromTable(cfg, "connectingPeriod", _dataSendingPeriod);
            // Let's immediately call data reading function and send the data because reading/sending periods changed.
            // This will also reset the reading and sending timers
            _dataProc();
            _dataSend();
        }
    }

    function _updCfgAlerts(cfg) {
        local alertsCfg            = getValFromTable(cfg, "alerts");
        local shockDetectedCfg     = getValFromTable(alertsCfg, "shockDetected");
        local temperatureHighCfg   = getValFromTable(alertsCfg, "temperatureHigh");
        local temperatureLowCfg    = getValFromTable(alertsCfg, "temperatureLow");
        local batteryLowCfg        = getValFromTable(alertsCfg, "batteryLow");
        local tamperingDetectedCfg = getValFromTable(alertsCfg, "tamperingDetected");

        if (shockDetectedCfg) {
            _allAlerts.shockDetected = false;
            mixTables(shockDetectedCfg, _alertsSettings.shockDetected);
            _configureShockDetection();
        }
        if (temperatureHighCfg || temperatureLowCfg) {
            _temperatureState = DP_TEMPERATURE_LEVEL.NORMAL;
            _allAlerts.temperatureHigh = false;
            _allAlerts.temperatureLow = false;
            mixTables(temperatureHighCfg, _alertsSettings.temperatureHigh);
            mixTables(temperatureLowCfg, _alertsSettings.temperatureLow);
        }
        if (batteryLowCfg) {
            _batteryState = DP_BATTERY_LEVEL.NORMAL;
            _allAlerts.batteryLow = false;
            mixTables(batteryLowCfg, _alertsSettings.batteryLow);
        }
        if (tamperingDetectedCfg) {
            _allAlerts.tamperingDetected = false;
            mixTables(tamperingDetectedCfg, _alertsSettings.tamperingDetected);
            _configureTamperingDetection();
        }
    }

    function _configureShockDetection() {
        if (_alertsSettings.shockDetected.enabled) {
            ::debug("Activating shock detection..", "DataProcessor");
            local settings = { "shockThreshold" : _alertsSettings.shockDetected.threshold };
            _ad.enableShockDetection(_onShockDetectedEvent.bindenv(this), settings);
        } else {
            _ad.enableShockDetection(null);
        }
    }

    function _configureTamperingDetection() {
        if (_alertsSettings.tamperingDetected.enabled) {
            ::debug("Activating tampering detection..", "DataProcessor");
            _pr.startPolling(_onLightDetectedEvent.bindenv(this), _alertsSettings.tamperingDetected.pollingPeriod);
        } else {
            _pr.stopPolling();
        }
    }

    /**
     *  Data sending timer callback function.
     */
    function _dataSendTimerCb() {
        _dataSend();
    }

    /**
     *  Send data
     */
    function _dataSend() {
        // Try to connect.
        // ReplayMessenger will automatically send all saved messages after that
        cm.connect();

        _dataSendingTimer && imp.cancelwakeup(_dataSendingTimer);
        _dataSendingTimer = imp.wakeup(_dataSendingPeriod,
                                       _dataSendTimerCb.bindenv(this));
    }

    /**
     *  Data reading and processing timer callback function.
     */
    function _dataProcTimerCb() {
        _dataProc();
    }

    /**
     *  Data and alerts reading and processing.
     */
    function _dataProc() {
        if (_dataReadingPromise) {
            return _dataReadingPromise;
        }

        // read temperature, check alert conditions
        _checkTemperature();

        // get cell info, read battery level
        _dataReadingPromise = Promise.all([_getCellInfo(), _checkBatteryLevel()])
        .finally(function(_) {
            // check if alerts have been triggered
            local alerts = [];
            foreach (key, val in _allAlerts) {
                if (val) {
                    alerts.append(key);
                    _allAlerts[key] = false;
                }
            }

            local cellInfo = _lastCellInfo || {};
            local lmStatus = _lm.getStatus();
            local flags = mixTables(_mm.getStatus().flags, lmStatus.flags);
            local location = lmStatus.location;
            local gnssInfo = lmStatus.gnssInfo;

            local dataMsg = {
                "trackerId": hardware.getdeviceid(),
                "timestamp": time(),
                "status": flags,
                "location": {
                    "timestamp": location.timestamp,
                    "type": location.type,
                    "accuracy": location.accuracy,
                    "lng": location.longitude,
                    "lat": location.latitude
                },
                "sensors": {},
                "alerts": alerts,
                "cellInfo": cellInfo,
                "gnssInfo": {}
            };

            (_temperature  != null) && (dataMsg.sensors.temperature  <- _temperature);
            (_batteryLevel != null) && (dataMsg.sensors.batteryLevel <- _batteryLevel);

            if (_lastGnssInfo == null || !deepEqual(_lastGnssInfo, gnssInfo)) {
                _lastGnssInfo = gnssInfo;
                dataMsg.gnssInfo = gnssInfo;
            }

            _lastCellInfo = null;

            ::debug("Message: " + JSONEncoder.encode(dataMsg), "DataProcessor");

            // ReplayMessenger saves the message till imp-device is connected
            rm.send(APP_RM_MSG_NAME.DATA, dataMsg, RM_IMPORTANCE_HIGH);
            ledIndication && ledIndication.indicate(LI_EVENT_TYPE.NEW_MSG);

            if (alerts.len() > 0) {
                ::info("Alerts:", "DataProcessor");
                foreach (item in alerts) {
                    ::info(item, "DataProcessor");
                }

                // If there is at least one alert, try to send data immediately
                _dataSend();
            }

            _dataReadingTimer && imp.cancelwakeup(_dataReadingTimer);
            _dataReadingTimer = imp.wakeup(_dataReadingPeriod,
                                           _dataProcTimerCb.bindenv(this));

            _dataReadingPromise = null;
        }.bindenv(this));
    }

    /**
     *  Read temperature, check alert conditions
     */
    function _checkTemperature() {
        try {
            _temperature = _ad.readTemperature();
        } catch (err) {
            ::error("Failed to read temperature: " + err, "DataProcessor");
            // Don't generate alerts and don't send temperature to the cloud
            _temperature = null;
            return;
        }

        ::debug("Temperature: " + _temperature, "DataProcessor");

        local tempHigh = _alertsSettings.temperatureHigh;
        local tempLow = _alertsSettings.temperatureLow;

        if (tempHigh.enabled) {
            if (_temperature > tempHigh.threshold && _temperatureState != DP_TEMPERATURE_LEVEL.HIGH) {
                _allAlerts.temperatureHigh = true;
                _temperatureState = DP_TEMPERATURE_LEVEL.HIGH;

                ledIndication && ledIndication.indicate(LI_EVENT_TYPE.ALERT_TEMP_HIGH);
            } else if (_temperatureState == DP_TEMPERATURE_LEVEL.HIGH &&
                       _temperature < (tempHigh.threshold - tempHigh.hysteresis)) {
                _temperatureState = DP_TEMPERATURE_LEVEL.NORMAL;
            }
        }

        if (tempLow.enabled) {
            if (_temperature < tempLow.threshold && _temperatureState != DP_TEMPERATURE_LEVEL.LOW) {
                _allAlerts.temperatureLow = true;
                _temperatureState = DP_TEMPERATURE_LEVEL.LOW;

                ledIndication && ledIndication.indicate(LI_EVENT_TYPE.ALERT_TEMP_LOW);
            } else if (_temperatureState == DP_TEMPERATURE_LEVEL.LOW &&
                       _temperature > (tempLow.threshold + tempLow.hysteresis)) {
                _temperatureState = DP_TEMPERATURE_LEVEL.NORMAL;
            }
        }
    }

    /**
     *  Read battery level, check alert conditions
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function _checkBatteryLevel() {
        return _bd.measureBattery()
        .then(function(level) {
            _batteryLevel = level.percent;

            ::debug("Battery level: " + _batteryLevel + "%", "DataProcessor");

            if (!_alertsSettings.batteryLow.enabled) {
                return;
            }

            local batteryLowThr = _alertsSettings.batteryLow.threshold;

            if (_batteryLevel < batteryLowThr && _batteryState == DP_BATTERY_LEVEL.NORMAL) {
                _allAlerts.batteryLow = true;
                _batteryState = DP_BATTERY_LEVEL.LOW;
            }

            if (_batteryLevel > batteryLowThr + DP_BATTERY_LEVEL_HYST) {
                _batteryState = DP_BATTERY_LEVEL.NORMAL;
            }
        }.bindenv(this), function(err) {
            ::error("Failed to get battery level: " + err, "DataProcessor");
            // Don't generate alerts and don't send battery level to the cloud
            _batteryLevel = null;
        }.bindenv(this));
    }

    function _getCellInfo() {
        if (_cellInfoPromise || !cm.isConnected()) {
            return _cellInfoPromise || Promise.resolve(null);
        }

        return _cellInfoPromise = Promise(function(resolve, reject) {
            const DP_GET_CELL_INFO_TIMEOUT = 5;

            // NOTE: This is a defense from the incorrect work of getcellinfo()
            local cbTimeoutTimer = imp.wakeup(DP_GET_CELL_INFO_TIMEOUT, function() {
                reject("imp.net.getcellinfo didn't call its callback!");
            }.bindenv(this));

            imp.net.getcellinfo(function(cellInfo) {
                imp.cancelwakeup(cbTimeoutTimer);
                _lastCellInfo = _extractCellInfoBG95(cellInfo);
                resolve(null);
            }.bindenv(this));
        }.bindenv(this))
        .fail(function(err) {
            ::error("Failed getting cell info: " + err, "DataProcessor");
        }.bindenv(this))
        .finally(function(_) {
            _cellInfoPromise = null;
        }.bindenv(this));
    }

    function _extractCellInfoBG95(cellInfo) {
        local res = {
            "timestamp": time(),
            "mode": null,
            "signalStrength": null,
            "mcc": null,
            "mnc": null
        };

        try {
            // Remove quote marks from strings
            do {
                local idx = cellInfo.find("\"");
                if (idx == null) {
                    break;
                }

                cellInfo = cellInfo.slice(0, idx) + (idx < cellInfo.len() - 1 ? cellInfo.slice(idx + 1) : "");
            } while (true);

            // Parse string 'cellInfo' into its three newline-separated parts
            local cellStrings = split(cellInfo, "\n");

            if (cellStrings.len() != 3) {
                throw "cell info must contain exactly 3 rows";
            }

            // AT+QCSQ
            // Response: <sysmode>,[,<rssi>[,<lte_rsrp>[,<lte_sinr>[,<lte_rsrq>]]]]
            local qcsq = split(cellStrings[1], ",");
            // AT+QNWINFO
            // Response: <Act>,<oper>,<band>,<channel>
            local qnwinfo = split(cellStrings[2], ",");

            res.mode = qcsq[0];
            res.signalStrength = qcsq[1].tointeger();
            res.mcc = qnwinfo[1].slice(0, 3);
            res.mnc = qnwinfo[1].slice(3);
        } catch (err) {
            ::error(format("Couldn't parse cell info: '%s'. Raw cell info:\n%s", err, cellInfo), "DataProcessor", true);
            return null;
        }

        return res;
    }

    /**
     * The handler is called when a shock event is detected.
     */
    function _onShockDetectedEvent() {
        _allAlerts.shockDetected = true;
        _dataProc();

        ledIndication && ledIndication.indicate(LI_EVENT_TYPE.ALERT_SHOCK);
    }

    /**
     *  The handler is called when a motion event is detected.
     *  @param {bool} eventType - true: motion started, false: motion stopped
     */
    function _onMotionEvent(eventType) {
        if (eventType) {
            _allAlerts.motionStarted = true;
            ledIndication && ledIndication.indicate(LI_EVENT_TYPE.ALERT_MOTION_STARTED);
        } else {
            _allAlerts.motionStopped = true;
            ledIndication && ledIndication.indicate(LI_EVENT_TYPE.ALERT_MOTION_STOPPED);
        }

        _dataProc();
    }

    /**
     *  The handler is called when a geofencing event is detected.
     *  @param {bool} eventType - true: geofence is entered, false: geofence is exited
     */
    function _onGeofencingEvent(eventType) {
        if (eventType) {
            _allAlerts.geofenceEntered = true;
        } else {
            _allAlerts.geofenceExited = true;
        }

        _dataProc();
    }

    /**
     *  The handler is called when repossession mode is activated
     */
    function _onRepossessionEvent() {
        _allAlerts.repossessionActivated = true;

        _dataProc();
    }

    /**
     *  This handler is called when a light detection event happens.
     *  @param {bool} eventType - true: light is detected, false: light is no longer present
     */
    function _onLightDetectedEvent(eventType) {
        if (eventType) {
            _allAlerts.tamperingDetected = true;

            _dataProc();
        }
    }
}

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


// GNSS options:
// Accuracy threshold of positioning, in meters
const LD_GNSS_ACCURACY = 50;
// The maximum positioning time, in seconds
const LD_GNSS_LOC_TIMEOUT = 55;
// The number of fails allowed before the cooldown period is activated
const LD_GNSS_FAILS_BEFORE_COOLDOWN = 3;
// Duration of the cooldown period, in seconds
const LD_GNSS_COOLDOWN_PERIOD = 300;

// U-blox UART baudrate
const LD_UBLOX_UART_BAUDRATE = 115200;
// U-blox location check (polling) period, in seconds
const LD_UBLOX_LOC_CHECK_PERIOD = 1;
// The minimum period of updating the offline assist data of u-blox, in seconds
const LD_ASSIST_DATA_UPDATE_MIN_PERIOD = 43200;

// File names used by LocationDriver
enum LD_FILE_NAMES {
    LAST_KNOWN_LOCATION = "lastKnownLocation"
}

// U-blox fix types enumeration
enum LD_UBLOX_FIX_TYPE {
    NO_FIX,
    DEAD_REC_ONLY,
    FIX_2D,
    FIX_3D,
    GNSS_DEAD_REC,
    TIME_ONLY
}

// Location Driver class.
// Determines the current position.
class LocationDriver {
    // u-blox module's power switch pin
    _ubxSwitchPin = null;
    // SPIFlashFileSystem instance. Used to store u-blox assist data and other data
    _storage = null;
    // Timestamp of the latest assist data check (download)
    _assistDataUpdateTs = 0;
    // Promise that resolves or rejects when the location has been obtained.
    // null if the location is not being obtained at the moment
    _gettingLocation = null;
    // Promise that resolves or rejects when the assist data has been obtained.
    // null if the assist data is not being obtained at the moment
    _gettingAssistData = null;
    // Fails counter for GNSS. If it exceeds the threshold, the cooldown period will be applied
    _gnssFailsCounter = 0;
    // ESP32Driver object
    _esp = null;
    // True if location using BLE devices is enabled, false otherwise
    _bleDevicesEnabled = false;
    // Known BLE devices
    _knownBLEDevices = null;
    // Extra information (e.g., number of GNSS satellites)
    _extraInfo = null;

    /**
     * Constructor for Location Driver
     */
    constructor() {
        _ubxSwitchPin = HW_UBLOX_POWER_EN_PIN;

        _storage = SPIFlashFileSystem(HW_LD_SFFS_START_ADDR, HW_LD_SFFS_END_ADDR);
        _storage.init();

        _extraInfo = {
            "gnss": {}
        };

        cm.onConnect(_onConnected.bindenv(this), "LocationDriver");
        _esp = ESP32Driver(HW_ESP_POWER_EN_PIN, HW_ESP_UART);
        _updateAssistData();
    }

    /**
     * Get the last known location (stored in the persistent storage)
     *
     * @return {table} with the following keys and values:
     *  "timestamp": UNIX time of the location,
     *  "type": location type ("gnss" / "wifi" / "cell" / "wifi+cell" / "ble"),
     *  "accuracy": location accuracy,
     *  "longitude": location longitude,
     *  "latitude": location latitude
     */
    function lastKnownLocation() {
        return _load(LD_FILE_NAMES.LAST_KNOWN_LOCATION, Serializer.deserialize.bindenv(Serializer));
    }

    /**
     * Configure BLE devices
     *
     * @param {boolean | null} enabled - If true, enable BLE location. If null, ignored
     * @param {table} [knownBLEDevices] - Known BLE devices (generic and iBeacon). If null, ignored
     *                                    NOTE: This class only stores a reference to the object with BLE devices. If this object
     *                                    is changed outside this class, this class will have the updated version of the object
     */
    function configureBLEDevices(enabled, knownBLEDevices = null) {
        knownBLEDevices && (_knownBLEDevices = knownBLEDevices);

        if (enabled && !_knownBLEDevices) {
            throw "Known BLE devices must be specified to enable location using BLE devices";
        }

        (enabled != null) && (_bleDevicesEnabled = enabled);
    }

    /**
     * Obtain and return the current location
     * - First, try to get GNSS fix
     * - If no success, try to obtain location using cell towers info
     *
     * @return {Promise} that:
     * - resolves with the current location if the operation succeeded
     * - rejects if the operation failed
     */
    function getLocation() {
        if (_gettingLocation) {
            ::debug("Already getting location", "LocationDriver");
            return _gettingLocation;
        }

        return _gettingLocation = _getLocationBLEDevices()
        .fail(function(err) {
            if (err == null) {
                ::debug("Location using BLE devices is disabled", "LocationDriver");
            } else {
                ::info("Couldn't get location using BLE devices: " + err, "LocationDriver");
            }

            return _getLocationGNSS();
        }.bindenv(this))
        .fail(function(err) {
            ::info("Couldn't get location using GNSS: " + err, "LocationDriver");
            return _getLocationCellTowersAndWiFi();
        }.bindenv(this))
        .then(function(location) {
            _gettingLocation = null;
            // Save this location as the last known one
            _save(location, LD_FILE_NAMES.LAST_KNOWN_LOCATION, Serializer.serialize.bindenv(Serializer));
            return location;
        }.bindenv(this), function(err) {
            ::info("Couldn't get location using WiFi networks and cell towers: " + err, "LocationDriver");
            _gettingLocation = null;
            return Promise.reject(null);
        }.bindenv(this));
    }

    /**
     * Get extra info (e.g., number of GNSS satellites)
     *
     * @return {table} with the following keys and values:
     *  - "gnss": a table with keys "satellitesUsed" and "timestamp"
     */
    function getExtraInfo() {
        return tableFullCopy(_extraInfo);
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Obtain the current location using GNSS
     *
     * @return {Promise} that:
     * - resolves with the current location if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function _getLocationGNSS() {
        if (_gnssFailsCounter >= LD_GNSS_FAILS_BEFORE_COOLDOWN) {
            return Promise.reject("Cooldown period is active");
        }

        local ubxDriver = _initUblox();
        ::debug("Switched ON the u-blox module", "LocationDriver");

        return _updateAssistData()
        .finally(function(_) {
            ::debug("Writing the UTC time to u-blox..", "LocationDriver");
            local ubxAssist = UBloxAssistNow(ubxDriver);
            ubxAssist.writeUtcTimeAssist();
            return _writeAssistDataToUBlox(ubxAssist);
        }.bindenv(this))
        .finally(function(_) {
            ::debug("Getting location using GNSS (u-blox)..", "LocationDriver");
            return Promise(function(resolve, reject) {
                local onTimeout = function() {
                    // Failed to obtain the location
                    // Increase the fails counter, disable the u-blox, and reject the promise

                    // If the fails counter equals to LD_GNSS_FAILS_BEFORE_COOLDOWN, we activate the cooldown period.
                    // After this period, the counter will be reset and GNSS will be available again
                    if (++_gnssFailsCounter == LD_GNSS_FAILS_BEFORE_COOLDOWN) {
                        ::debug("GNSS cooldown period activated", "LocationDriver");

                        local onCooldownPeriodFinish = function() {
                            ::debug("GNSS cooldown period finished", "LocationDriver");
                            _gnssFailsCounter = 0;
                        }.bindenv(this);

                        imp.wakeup(LD_GNSS_COOLDOWN_PERIOD, onCooldownPeriodFinish);
                    }

                    _disableUBlox();
                    reject("Timeout");
                }.bindenv(this);

                local timeoutTimer = imp.wakeup(LD_GNSS_LOC_TIMEOUT, onTimeout);

                local onFix = function(location) {
                    ::info("Got location using GNSS", "LocationDriver");
                    ::debug(location, "LocationDriver");

                    // Successful location!
                    // Zero the fails counter, cancel the timeout timer, disable the u-blox, and resolve the promise
                    _gnssFailsCounter = 0;
                    imp.cancelwakeup(timeoutTimer);
                    _disableUBlox();
                    resolve(location);
                }.bindenv(this);

                // Enable Position Velocity Time Solution messages
                ubxDriver.enableUbxMsg(UBX_MSG_PARSER_CLASS_MSG_ID.NAV_PVT, LD_UBLOX_LOC_CHECK_PERIOD, _onUBloxNavMsgFunc(onFix));
            }.bindenv(this));
        }.bindenv(this));
    }

    /**
     * Obtain the current location using cell towers info and WiFi
     *
     * @return {Promise} that:
     * - resolves with the current location if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function _getLocationCellTowersAndWiFi() {
        ::debug("Getting location using cell towers and WiFi..", "LocationDriver");

        cm.keepConnection("LocationDriver", true);

        local scannedWifis = null;
        local scannedTowers = null;
        local locType = null;

        // Run WiFi scanning in the background
        local scanWifiPromise = _esp.scanWiFiNetworks()
        .then(function(wifis) {
            scannedWifis = wifis.len() > 0 ? wifis : null;
        }.bindenv(this), function(err) {
            ::error("Couldn't scan WiFi networks: " + err, "LocationDriver");
        }.bindenv(this));

        return cm.connect()
        .then(function(_) {
            scannedTowers = BG9xCellInfo.scanCellTowers();
            scannedTowers = (scannedTowers && scannedTowers.cellTowers.len() > 0) ? scannedTowers : null;
            // Wait until the WiFi scanning is finished (if not yet)
            return scanWifiPromise;
        }.bindenv(this), function(_) {
            throw "Couldn't connect to the server";
        }.bindenv(this))
        .then(function(_) {
            local locationData = {};

            if (scannedWifis && scannedTowers) {
                locationData.wifiAccessPoints <- scannedWifis;
                locationData.radioType <- scannedTowers.radioType;
                locationData.cellTowers <- scannedTowers.cellTowers;
                locType = "wifi+cell";
            } else if (scannedWifis) {
                locationData.wifiAccessPoints <- scannedWifis;
                locType = "wifi";
            } else if (scannedTowers) {
                locationData.radioType <- scannedTowers.radioType;
                locationData.cellTowers <- scannedTowers.cellTowers;
                locType = "cell";
            } else {
                throw "No towers and WiFi scanned";
            }

            ::debug("Sending results to the agent..", "LocationDriver");

            return _requestToAgent(APP_RM_MSG_NAME.LOCATION_CELL_WIFI, locationData)
            .fail(function(err) {
                throw "Error sending a request to the agent: " + err;
            }.bindenv(this));
        }.bindenv(this))
        .then(function(resp) {
            cm.keepConnection("LocationDriver", false);

            if (resp == null) {
                throw "No location received from the agent";
            }

            ::info("Got location using cell towers and/or WiFi", "LocationDriver");
            ::debug(resp, "LocationDriver");

            return {
                // Here we assume that if the device is connected, its time is synced
                "timestamp": time(),
                "type": locType,
                "accuracy": resp.accuracy,
                "longitude": resp.location.lng,
                "latitude": resp.location.lat
            };
        }.bindenv(this), function(err) {
            cm.keepConnection("LocationDriver", false);
            throw err;
        }.bindenv(this));
    }

    /**
     * Obtain the current location using BLE devices
     *
     * @return {Promise} that:
     * - resolves with the current location if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function _getLocationBLEDevices() {
        // Default accuracy
        const LD_BLE_BEACON_DEFAULT_ACCURACY = 10;

        if (!_bleDevicesEnabled) {
            // Reject with null to indicate that the feature is disabled
            return Promise.reject(null);
        }

        ::debug("Getting location using BLE devices..", "LocationDriver");

        local knownGeneric = _knownBLEDevices.generic;
        local knownIBeacons = _knownBLEDevices.iBeacon;

        return _esp.scanBLEAdverts()
        .then(function(adverts) {
            // Table of "recognized" advertisements (for which the location is known) and their locations
            local recognized = {};

            foreach (advert in adverts) {
                if (advert.address in knownGeneric) {
                    ::debug("A generic BLE device with known location found: " + advert.address, "LocationDriver");

                    recognized[advert] <- knownGeneric[advert.address];
                    continue;
                }

                local parsed = _parseIBeaconPacket(advert.advData);

                if (parsed && parsed.uuid  in knownIBeacons
                           && parsed.major in knownIBeacons[parsed.uuid]
                           && parsed.minor in knownIBeacons[parsed.uuid][parsed.major]) {
                    local iBeaconInfo = format("UUID %s, Major %s, Minor %s", parsed.uuid, parsed.major, parsed.minor);
                    ::debug(format("An iBeacon device with known location found: %s, %s", advert.address, iBeaconInfo), "LocationDriver");

                    recognized[advert] <- knownIBeacons[parsed.uuid][parsed.major][parsed.minor];
                }
            }

            if (recognized.len() == 0) {
                return Promise.reject("No known devices available");
            }

            local closestDevice = null;
            foreach (advert, _ in recognized) {
                if (closestDevice == null || closestDevice.rssi < advert.rssi) {
                    closestDevice = advert;
                }
            }

            ::info("Got location using BLE devices", "LocationDriver");
            ::debug("The closest BLE device with known location: " + closestDevice.address, "LocationDriver");
            ::debug(recognized[closestDevice], "LocationDriver");

            return {
                "timestamp": time(),
                "type": "ble",
                "accuracy": LD_BLE_BEACON_DEFAULT_ACCURACY,
                "longitude": recognized[closestDevice].lng,
                "latitude": recognized[closestDevice].lat
            };
        }.bindenv(this), function(err) {
            throw "Couldn't scan BLE devices: " + err;
        }.bindenv(this));
    }

    /**
     * Handler called every time imp-device becomes connected
     */
    function _onConnected() {
        _updateAssistData();
    }

    /**
     * Update GNSS Assist data if needed
     *
     * @return {Promise} that always resolves
     */
    function _updateAssistData() {
        if (_gettingAssistData) {
            ::debug("Already getting u-blox assist data", "LocationDriver");
            return _gettingAssistData;
        }

        local dataIsUpToDate = time() < _assistDataUpdateTs + LD_ASSIST_DATA_UPDATE_MIN_PERIOD;

        if (dataIsUpToDate || !cm.isConnected()) {
            dataIsUpToDate && ::debug("U-blox assist data is up to date...", "LocationDriver");
            return Promise.resolve(null);
        }

        ::debug("Requesting u-blox assist data...", "LocationDriver");

        return _gettingAssistData = _requestToAgent(APP_RM_MSG_NAME.GNSS_ASSIST)
        .then(function(data) {
            _gettingAssistData = null;

            if (data == null) {
                ::info("No u-blox assist data received", "LocationDriver");
                return;
            }

            ::info("U-blox assist data received", "LocationDriver");

            _assistDataUpdateTs = time();
            _eraseStaleUBloxAssistData();
            _saveUBloxAssistData(data);
        }.bindenv(this), function(err) {
            _gettingAssistData = null;
            ::info("U-blox assist data request failed: " + err, "LocationDriver");
        }.bindenv(this));
    }

    /**
     * Send a request to imp-agent
     *
     * @param {enum} name - ReplayMessenger message name (APP_RM_MSG_NAME)
     * @param {Any serializable type | null} [data] - data, optional
     *
     * @return {Promise} that:
     * - resolves with the response (if any) if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function _requestToAgent(name, data = null) {
        return Promise(function(resolve, reject) {
            local onMsgAck = function(msg, resp) {
                // Reset the callbacks because the request is finished
                rm.onAck(null, name);
                rm.onFail(null, name);
                resolve(resp);
            }.bindenv(this);

            local onMsgFail = function(msg, error) {
                // Reset the callbacks because the request is finished
                rm.onAck(null, name);
                rm.onFail(null, name);
                reject(error);
            }.bindenv(this);

            // Set temporary callbacks for this request
            rm.onAck(onMsgAck.bindenv(this), name);
            rm.onFail(onMsgFail.bindenv(this), name);
            // Send the request to the agent
            rm.send(name, data);
        }.bindenv(this));
    }

    /**
     * Parse the iBeacon packet (if any) from BLE advertisement data
     *
     * @param {blob} data - BLE advertisement data
     *
     * @return {table | null} Parsed iBeacon packet or null if no iBeacon packet found
     *  The keys and values of the table:
     *     "uuid"  : {string}  - UUID (16 bytes).
     *     "major" : {string} - Major (from 0 to 65535).
     *     "minor" : {string} - Minor (from 0 to 65535).
     */
    function _parseIBeaconPacket(data) {
        // Packet length: 0x1A = 26 bytes
        // Packet type: 0xFF = Custom Manufacturer Packet
        // Manufacturer ID: 0x4C00 (little-endian) = Apple’s Bluetooth Sig ID
        // Sub-packet type: 0x02 = iBeacon
        // Sub-packet length: 0x15 = 21 bytes
        const LD_IBEACON_PREFIX = "\x1A\xFF\x4C\x00\x02\x15";
        const LD_IBEACON_DATA_LEN = 27;

        local dataStr = data.tostring();

        if (dataStr.len() < LD_IBEACON_DATA_LEN || dataStr.find(LD_IBEACON_PREFIX) == null) {
            return null;
        }

        local checkPrefix = function(startIdx) {
            return dataStr.slice(startIdx, startIdx + LD_IBEACON_PREFIX.len()) == LD_IBEACON_PREFIX;
        };

        // Advertisement data may consist of several sub-packets. Every packet contains its length in the first byte.
        // We are jumping across these packets and checking if some of them contains the prefix we are looking for
        local packetStartIdx = 0;
        while (!checkPrefix(packetStartIdx)) {
            // Add up the sub-packet's length to jump to the next one
            packetStartIdx += data[packetStartIdx] + 1;

            // If we see that there will surely be no iBeacon packet in further bytes, we stop
            if (packetStartIdx + LD_IBEACON_DATA_LEN > data.len()) {
                return null;
            }
        }

        data.seek(packetStartIdx + LD_IBEACON_PREFIX.len());

        return {
            // Get a string like "74d2515660e6444ca177a96e67ecfc5f" without "0x" prefix
            "uuid": utilities.blobToHexString(data.readblob(16)).slice(2),
            // We convert them to strings here just for convenience - these values are strings in the table (JSON) of known BLE devices
            "major": ((data.readn('b') << 8) | data.readn('b')).tostring(),
            "minor": ((data.readn('b') << 8) | data.readn('b')).tostring(),
        }
    }

    // -------------------- UBLOX-SPECIFIC METHODS -------------------- //

    /**
     * Initialize u-blox module and UBloxM8N library
     *
     * @return {object} UBloxM8N library instance
     */
    function _initUblox() {
        _ubxSwitchPin.configure(DIGITAL_OUT, 1);

        local ubxDriver = UBloxM8N(HW_UBLOX_UART);
        local ubxSettings = {
            "outputMode"   : UBLOX_M8N_MSG_MODE.UBX_ONLY,
            "inputMode"    : UBLOX_M8N_MSG_MODE.BOTH
        };


        ubxDriver.configure(ubxSettings);

        return ubxDriver;
    }

    /**
     * Create a handler called when a navigation message received from the u-blox module
     *
     * @param {function} onFix - Function to be called in case of successful getting of a GNSS fix
     *         onFix(fix), where
     *         @param {table} fix - GNSS fix (location) data
     *
     * @return {function} Handler called when a navigation message received
     */
    function _onUBloxNavMsgFunc(onFix) {
        // A valid timestamp will surely be greater than this value (01.01.2021)
        const LD_VALID_TS = 1609459200;

        return function(payload) {
            local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.NAV_PVT](payload);


            if (parsed.error != null) {
                // NOTE: This may be printed as binary data
                ::error(parsed.error, "LocationDriver");
                ::debug("The full payload containing the error: " + payload, "LocationDriver");
                return;
            }


            if (!("satellitesUsed" in _extraInfo.gnss) || _extraInfo.gnss.satellitesUsed != parsed.numSV) {
                ::debug(format("Current u-blox info: fixType %d, satellites %d, accuracy %d",
                        parsed.fixType, parsed.numSV, _getUBloxAccuracy(parsed.hAcc)), "LocationDriver");
            }

            _extraInfo.gnss.satellitesUsed <- parsed.numSV;
            _extraInfo.gnss.timestamp <- time();

            // Check fixtype
            if (parsed.fixType >= LD_UBLOX_FIX_TYPE.FIX_3D) {
                local accuracy = _getUBloxAccuracy(parsed.hAcc);

                if (accuracy <= LD_GNSS_ACCURACY) {
                    onFix({
                        // If we don't have the valid time, we take it from the location data
                        "timestamp": time() > LD_VALID_TS ? time() : _dateToTimestamp(parsed),
                        "type": "gnss",
                        "accuracy": accuracy,
                        "longitude": UbxMsgParser.toDecimalDegreeString(parsed.lon).tofloat(),
                        "latitude": UbxMsgParser.toDecimalDegreeString(parsed.lat).tofloat()
                    });
                }
            }
        }.bindenv(this);
    }

    /**
     * Disable u-blox module
     */
    function _disableUBlox() {
        // Disable the UART to save power
        HW_UBLOX_UART.disable();
        _ubxSwitchPin.disable();
        ::debug("Switched OFF the u-blox module", "LocationDriver");
    }

    /**
     * Write the applicable u-blox assist data (if any) saved in the storage to the u-blox module
     *
     * @param {object} ubxAssist - U-blox Assist Now library instance
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function _writeAssistDataToUBlox(ubxAssist) {
        // This timeout should be long enough to let the ubxAssist.writeAssistNow() process be finished.
        // If it's not finished before this timeout, an unexpected write to the UART (which may be disabled) can occur
        const LD_ASSIST_DATA_WRITE_TIMEOUT = 120;

        return Promise(function(resolve, reject) {
            local assistData = _readUBloxAssistData();
            if (assistData == null) {
                return reject(null);
            }

            local onDone = function(errors) {
                if (!errors) {
                    ::debug("Assist data has been written to u-blox successfully", "LocationDriver");
                    return resolve(null);
                }

                ::info(format("Assist data has been written to u-blox successfully except %d assist messages", errors.len()), "LocationDriver");
                foreach(err in errors) {
                    // Log errors encountered
                    ::debug(err, "LocationDriver");
                }

                reject(null);
            }.bindenv(this);

            ::debug("Writing assist data to u-blox..", "LocationDriver");
            ubxAssist.writeAssistNow(assistData, onDone);

            // NOTE: Resolve this Promise after a timeout because it's been noticed that
            // the callback is not always called by the writeAssistNow() method
            imp.wakeup(LD_ASSIST_DATA_WRITE_TIMEOUT, reject);
        }.bindenv(this));
    }

    /**
     * Read the applicable u-blox assist data (if any) from in the storage
     *
     * @return {blob | null} The assist data read or null if no applicable assist data found
     */
    function _readUBloxAssistData() {
        const LD_DAY_SEC = 86400;

        ::debug("Reading u-blox assist data..", "LocationDriver");

        try {
            local chosenFile = null;
            local todayFileName = UBloxAssistNow.getDateString();
            local tomorrowFileName = UBloxAssistNow.getDateString(date(time() + LD_DAY_SEC));
            local yesterdayFileName = UBloxAssistNow.getDateString(date(time() - LD_DAY_SEC));

            if (_storage.fileExists(todayFileName)) {
                chosenFile = todayFileName;
            } else if (_storage.fileExists(tomorrowFileName)) {
                chosenFile = tomorrowFileName;
            } else if (_storage.fileExists(yesterdayFileName)) {
                chosenFile = yesterdayFileName;
            }

            if (chosenFile == null) {
                ::debug("No applicable u-blox assist data found", "LocationDriver");
                return null;
            }

            ::debug("Found applicable u-blox assist data with the following date: " + chosenFile, "LocationDriver");

            local data = _load(chosenFile);
            data.seek(0, 'b');

            return data;
        } catch (err) {
            ::error("Couldn't read u-blox assist data: " + err, "LocationDriver");
        }

        return null;
    }

    /**
     * Save u-blox assist data to the storage
     *
     * @param {blob} data - Assist data
     */
    function _saveUBloxAssistData(data) {
        ::debug("Saving u-blox assist data..", "LocationDriver");

        foreach (date, assistMsgs in data) {
            _save(assistMsgs, date);
        }
    }

    /**
     * Erase stale u-blox assist data from the storage
     */
    function _eraseStaleUBloxAssistData() {
        const LD_UBLOX_AD_INTEGER_DATE_MIN = 20220101;
        const LD_UBLOX_AD_INTEGER_DATE_MAX = 20990101;

        ::debug("Erasing stale u-blox assist data..", "LocationDriver");

        try {
            local files = _storage.getFileList();
            // Since the date has the following format YYYYMMDD, we can compare dates as integer numbers
            local yesterday = UBloxAssistNow.getDateString(date(time() - LD_DAY_SEC)).tointeger();

            ::debug("There are " + files.len() + " file(s) in the storage", "LocationDriver");

            foreach (file in files) {
                local name = file.fname;
                local erase = false;

                try {
                    // Any assist data file has a name that can be converted to an integer
                    local fileDate = name.tointeger();

                    // We need to find assist files for dates before yesterday
                    if (fileDate > LD_UBLOX_AD_INTEGER_DATE_MIN && fileDate < LD_UBLOX_AD_INTEGER_DATE_MAX) {
                        erase = fileDate < yesterday;
                    }
                } catch (_) {
                    // If the file's name can't be converted to an integer, this is not an assist data file and we must not erase it
                }

                if (erase) {
                    ::debug("Erasing u-blox assist data file: " + name, "LocationDriver");
                    // Erase stale assist message
                    _storage.eraseFile(name);
                }
            }
        } catch (err) {
            ::error("Couldn't erase stale u-blox assist data: " + err, "LocationDriver");
        }
    }

    /**
     * Get the accuracy of a u-blox GNSS fix
     *
     * @param {blob} hAcc - Accuracy, 32 bit unsigned integer (little endian)
     *
     * @return {integer} The accuracy of a u-blox GNSS fix
     */
    function _getUBloxAccuracy(hAcc) {
        // Mean earth radius in meters (https://en.wikipedia.org/wiki/Great-circle_distance)
        const LD_EARTH_RAD = 6371009;

        // Squirrel only handles 32 bit signed integers
        // hAcc (horizontal accuracy estimate in mm) is an unsigned 32 bit integer
        // Read as signed integer and if value is negative set to
        // highly inaccurate default
        hAcc.seek(0, 'b');
        local gpsAccuracy = hAcc.readn('i');
        return (gpsAccuracy < 0) ? LD_EARTH_RAD : gpsAccuracy / 1000.0;
    }


    // -------------------- STORAGE METHODS -------------------- //

    function _save(data, fileName, encoder = null) {
        _erase(fileName);

        try {
            local file = _storage.open(fileName, "w");
            file.write(encoder ? encoder(data) : data);
            file.close();
        } catch (err) {
            ::error(format("Couldn't save data (file name = %s): %s", fileName, err), "LocationDriver");
        }
    }

    function _load(fileName, decoder = null) {
        try {
            if (_storage.fileExists(fileName)) {
                local file = _storage.open(fileName, "r");
                local data = file.read();
                file.close();
                return decoder ? decoder(data) : data;
            }
        } catch (err) {
            ::error(format("Couldn't load data (file name = %s): %s", fileName, err), "LocationDriver");
        }

        return null;
    }

    function _erase(fileName) {
        try {
            // Erase the existing file if any
            _storage.fileExists(fileName) && _storage.eraseFile(fileName);
        } catch (err) {
            ::error(format("Couldn't erase data (file name = %s): %s", fileName, err), "LocationDriver");
        }
    }

    // -------------------- HELPER METHODS -------------------- //

    /**
     * Convert a date-time to a UNIX timestamp
     *
     * @param {table} date - A table containing "year", "month", "day", "hour", "min" and "sec" fields
     *                       IMPORTANT: "month" must be from 1 to 12. But the standard date() function returns 0-11
     *
     * @return {integer} The UNIX timestamp
     */
    function _dateToTimestamp(date) {
        try {
            local y = date.year;
            // IMPORTANT: Here we assume that month is from 1 to 12. But the standard date() function returns 0-11
            local m = date.month;
            local d = date.day;
            local hrs = date.hour;
            local min = date.min;
            local sec = date.sec;
            local ts;

            // January and February are counted as months 13 and 14 of the previous year
            if (m <= 2) {
                m += 12;
                y -= 1;
            }

            // Convert years to days
            ts = (365 * y) + (y / 4) - (y / 100) + (y / 400);
            // Convert months to days
            ts += (30 * m) + (3 * (m + 1) / 5) + d;
            // Unix time starts on January 1st, 1970
            ts -= 719561;
            // Convert days to seconds
            ts *= 86400;
            // Add hours, minutes and seconds
            ts += (3600 * hrs) + (60 * min) + sec;

            return ts;
        } catch (err) {
            ::error("Invalid date object passed: " + err, "LocationDriver");
            return 0;
        }
    }
}

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


// SIM Updater class
// Initiates SIM OTA update and holds the connection for specified time to let the SIM update
class SimUpdater {
    _enabled = false;
    _duration = null;
    _keepConnectionTimer = null;

    /**
     *  Start SIM updater
     *
     *  @param {table} cfg - Table with the full configuration.
     *                       For details, please, see the documentation
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function start(cfg) {
        updateCfg(cfg);

        return Promise.resolve(null);
    }

    /**
     * Update configuration
     *
     * @param {table} cfg - Configuration. May be partial.
     *                      For details, please, see the documentation
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function updateCfg(cfg) {
        local simUpdateCfg = getValFromTable(cfg, "simUpdate");
        _enabled = getValFromTable(simUpdateCfg, "enabled", _enabled);
        _duration = getValFromTable(simUpdateCfg, "duration", _duration);

        if (simUpdateCfg) {
            _enabled ? _enable() : _disable();
        }

        return Promise.resolve(null);
    }

    function _enable() {
        // Maximum server flush duration (sec) before forcing SIM-OTA
        const SU_SERVER_FLUSH_TIMEOUT = 5;

        ::debug("Enabling SIM OTA updates..", "SimUpdater");

        local onConnected = function() {
            if (_keepConnectionTimer) {
                return;
            }

            ::info("Forcing SIM OTA update..", "SimUpdater");

            // Without server.flush() call we can face very often failures in forcing SIM-OTA
            server.flush(SU_SERVER_FLUSH_TIMEOUT);

            if (BG96_Modem.forceSuperSimOTA()) {
                ::debug("SIM OTA call succeeded. Now keeping the device connected for " + _duration + " seconds", "SimUpdater");

                cm.keepConnection("SimUpdater", true);

                local complete = function() {
                    ::debug("Stopped keeping the device connected", "SimUpdater");

                    _keepConnectionTimer = null;
                    cm.keepConnection("SimUpdater", false);
                }.bindenv(this);

                _keepConnectionTimer = imp.wakeup(_duration, complete);
            } else {
                ::error("SIM OTA call failed", "SimUpdater");
            }
        }.bindenv(this);

        cm.onConnect(onConnected, "SimUpdater");
        cm.isConnected() && onConnected();
    }

    function _disable() {
        if (_keepConnectionTimer) {
            imp.cancelwakeup(_keepConnectionTimer);
            _keepConnectionTimer = null;
        }

        cm.onConnect(null, "SimUpdater");
        cm.keepConnection("SimUpdater", false);

        ::debug("SIM OTA updates disabled", "SimUpdater");
    }
}


// Main application on Imp-Device: does the main logic of the application

// Connection Manager configuration constants:
// Maximum time allowed for the imp to connect to the server before timing out, in seconds
const APP_CM_CONNECT_TIMEOUT = 180.0;
// Delay before automatic disconnection if there are no connection consumers, in seconds
const APP_CM_AUTO_DISC_DELAY = 10.0;
// Maximum time allowed for the imp to be connected to the server, in seconds
const APP_CM_MAX_CONNECTED_TIME = 180.0;

// Replay Messenger configuration constants:
// The maximum message send rate,
// ie. the maximum number of messages the library allows to be sent in a second
const APP_RM_MSG_SENDING_MAX_RATE = 3;
// The maximum number of messages to queue at any given time when replaying
const APP_RM_MSG_RESEND_LIMIT = 3;

// Send buffer size, in bytes
const APP_SEND_BUFFER_SIZE = 8192;

class Application {
    /**
     * Application Constructor
     */
    constructor() {

        // Create and intialize Connection Manager
        // NOTE: This needs to be called as early in the code as possible
        // in order to run the application without a connection to the Internet
        // (it sets the appropriate send timeout policy)
        _initConnectionManager();

        local outStream = UartOutputStream(HW_LOGGING_UART);
        Logger.setOutputStream(outStream);

        ::info("Application Version: " + APP_VERSION);

        ledIndication = LedIndication(HW_LED_RED_PIN, HW_LED_GREEN_PIN, HW_LED_BLUE_PIN);

        // Switch off all flip-flops by default (except the ublox's backup pin)
        local flipFlops = [HW_ESP_POWER_EN_PIN, HW_LDR_POWER_EN_PIN];
        foreach (flipFlop in flipFlops) {
            flipFlop.configure(DIGITAL_OUT, 0);
            flipFlop.disable();
        }

        // Keep the u-blox backup pin always on
        HW_UBLOX_BACKUP_PIN.configure(DIGITAL_OUT, 1);

        _startSystemMonitoring();

        // Create and intialize Replay Messenger
        _initReplayMessenger()
        .then(function(_) {
            HW_ACCEL_I2C.configure(CLOCK_SPEED_400_KHZ);

            // Create and initialize Battery Monitor
            local batteryMon = BatteryMonitor(HW_BAT_LEVEL_POWER_EN_PIN, HW_BAT_LEVEL_PIN);
            // Create and initialize Photoresistor
            local photoresistor = Photoresistor(HW_LDR_POWER_EN_PIN, HW_LDR_PIN);
            // Create and initialize Location Driver
            local locationDriver = LocationDriver();
            // Create and initialize Accelerometer Driver
            local accelDriver = AccelerometerDriver(HW_ACCEL_I2C, HW_ACCEL_INT_PIN);
            // Create and initialize Location Monitor
            local locationMon = LocationMonitor(locationDriver);
            // Create and initialize Motion Monitor
            local motionMon = MotionMonitor(accelDriver, locationMon);
            // Create and initialize Data Processor
            local dataProc = DataProcessor(locationMon, motionMon, accelDriver, batteryMon, photoresistor);
            // Create and initialize SIM Updater
            local simUpdater = SimUpdater();
            // Create and initialize Cfg Manager
            local cfgManager = CfgManager([locationMon, motionMon, dataProc, simUpdater]);
            // Start Cfg Manager
            cfgManager.start();
        }.bindenv(this))
        .fail(function(err) {
            ::error("Error during initialization: " + err);
            pm.enterEmergencyMode("Error during initialization: " + err);
        }.bindenv(this));
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Create and intialize Connection Manager
     */
    function _initConnectionManager() {
        imp.setsendbuffersize(APP_SEND_BUFFER_SIZE);

        // Customized Connection Manager is used
        local cmConfig = {
            "blinkupBehavior"    : CM_BLINK_ON_CONNECT,
            "errorPolicy"        : RETURN_ON_ERROR_NO_DISCONNECT,
            "connectTimeout"     : APP_CM_CONNECT_TIMEOUT,
            "autoDisconnectDelay": APP_CM_AUTO_DISC_DELAY,
            "maxConnectedTime"   : APP_CM_MAX_CONNECTED_TIME
        };
        cm = CustomConnectionManager(cmConfig);
        cm.connect();
    }

    /**
     * Create and intialize Replay Messenger
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects with if the operation failed
     */
    function _initReplayMessenger() {
        // Configure and intialize SPI Flash Logger
        local sfLogger = SPIFlashLogger(HW_RM_SFL_START_ADDR, HW_RM_SFL_END_ADDR);

        // Configure and intialize Replay Messenger.
        // Customized Replay Messenger is used.
        local rmConfig = {
            "debug"      : false,
            "maxRate"    : APP_RM_MSG_SENDING_MAX_RATE,
            "resendLimit": APP_RM_MSG_RESEND_LIMIT
        };
        rm = CustomReplayMessenger(sfLogger, rmConfig);
        rm.confirmResend(_confirmResend.bindenv(this));

        return Promise(function(resolve, reject) {
            rm.init(resolve);
        }.bindenv(this));
    }

    /**
     * Start system monitoring (boot time, wake reason, free RAM)
     */
    function _startSystemMonitoring() {
        // Free RAM Checking period (only when the device is connected), in seconds
        const APP_CHECK_FREE_MEM_PERIOD = 2.0;

        local wkup = imp.wakeup.bindenv(imp);
        local getFreeMem = imp.getmemoryfree.bindenv(imp);
        local checkMemTimer = null;

        local bootTime = time();
        local wakeReason = hardware.wakereason();
        local curFreeMem = getFreeMem();
        local minFreeMem = 0x7FFFFFFF;

        local checkFreeMem = function() {
            checkMemTimer && imp.cancelwakeup(checkMemTimer);

            curFreeMem = getFreeMem();
            if (minFreeMem > curFreeMem) {
                minFreeMem = curFreeMem;
            }

            cm.isConnected() && (checkMemTimer = wkup(APP_CHECK_FREE_MEM_PERIOD, callee()));
        }.bindenv(this);

        local onConnected = function() {
            checkFreeMem();
            ::info(format("Boot timestamp %i, wake reason %i, free memory: cur %i bytes, min %i bytes",
                          bootTime,
                          wakeReason,
                          curFreeMem,
                          minFreeMem));
        }.bindenv(this);

        cm.isConnected() && onConnected();
        cm.onConnect(onConnected, "SystemMonitoring");
    }

    /**
     * A handler used by Replay Messenger to decide if a message should be re-sent
     *
     * @param {Message} message - The message (an instance of class Message) being replayed
     *
     * @return {boolean} - `true` to confirm message resending or `false` to drop the message
     */
    function _confirmResend(message) {
        // Resend all messages with the specified names
        local name = message.payload.name;
        return name == APP_RM_MSG_NAME.DATA;
    }

    /**
     * Erase SPI flash
     */
    function _eraseFlash() {
        ::info(format("Erasing SPI flash from 0x%x to 0x%x...", HW_ERASE_FLASH_START_ADDR, HW_ERASE_FLASH_END_ADDR));

        local spiflash = hardware.spiflash;
        spiflash.enable();

        for (local addr = HW_ERASE_FLASH_START_ADDR; addr < HW_ERASE_FLASH_END_ADDR; addr += 0x1000) {
            spiflash.erasesector(addr);
        }

        spiflash.disable();
        ::info("Erasing finished!");
    }
}

// ---------------------------- THE MAIN CODE ---------------------------- //

// Connection Manager, controls connection with Imp-Agent
cm <- null;

// Replay Messenger, communicates with Imp-Agent
rm <- null;

// LED indication
ledIndication <- null;

// Used to track the shipping of the device. Once the device has been shipped,
// the photoresistor will detect the light
local photoresistor = Photoresistor(HW_LDR_POWER_EN_PIN, HW_LDR_PIN);

// Callback to be called by Production Manager if it allows to run the main application
local startApp = function() {
    // Stop polling as we are going to start the main app => the device has already been shipped.
    // This is guaranteed to be called after (!) the startPolling() call as the startApp callback
    // is called asynchronously (using imp.wakeup)
    photoresistor.stopPolling();
    // Run the application
    ::app <- Application();
};

pm <- ProductionManager(startApp, true);
pm.start();

// If woken by the photoresistor (the wake-up pin was HIGH), the device has been shipped
if (hardware.wakereason() == WAKEREASON_PIN) {
    pm.shipped();
} else {
    local onLightDetected = function(_) {
        photoresistor.stopPolling();
        pm.shipped();
    }.bindenv(this);

    // Start polling to be sure we will not miss light detection while the device is
    // awake (= the wake-up pin is not working for the light detection).
    // Also, this will switch ON (via a flip-flop) the photoresistor and configure the wake-up
    // pin so the light detection is enabled during the deep sleep
    photoresistor.startPolling(onLightDetected);
}

