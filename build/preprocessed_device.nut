//line 5 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/not_for_uploading/my_main.device.nut"

//line 1 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/Main.device.nut"
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
#require "HTS221.device.lib.nut:2.0.2"
#require "UBloxM8N.device.lib.nut:1.0.1"
#require "UbxMsgParser.lib.nut:2.0.1"
#require "UBloxAssistNow.device.lib.nut:0.1.0"

//line 1 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/shared/Version.shared.nut"
// Application Version
const APP_VERSION = "1.3.0";
//line 1 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/shared/Constants.shared.nut"
// Constants common for the imp-agent and the imp-device

// ReplayMessenger message names
enum APP_RM_MSG_NAME {
    DATA = "data",
    GNSS_ASSIST = "gnssAssist",
    LOCATION_CELL_WIFI = "locationCellAndWiFi"
}

// Init latitude value (North Pole)
const INIT_LATITUDE = 90.0;

// Init longitude value (Greenwich)
const INIT_LONGITUDE = 0.0;
//line 1 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/shared/Logger/Logger.shared.nut"
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
    }
}

// Setup global variables:
// the logger should be used like the following: `::info("log text", "optional log source")`
::debug <- Logger.debug.bindenv(Logger);
::info  <- Logger.info.bindenv(Logger);
::error <- Logger.error.bindenv(Logger);

Logger.setLogLevelStr("INFO");

//line 20 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/Main.device.nut"

//line 1 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/shared/Logger/stream/Logger.IOutputStream.shared.nut"
/**
 * Logger output stream interface
 */
Logger.IOutputStream <- class {
    //  ------ PUBLIC FUNCTIONS TO OVERRIDE  ------- //
    function write(data) { throw "The Write method must be implemented in an inherited class" }
    function flush() { throw "The Flush method must be implemented in an inherited class" }
    function close() { throw "The Close method must be implemented in an inherited class" }
};

//line 2 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/shared/Logger/stream/UartOutputStream.device.nut"

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
//line 24 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/Main.device.nut"

//line 2 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/LedIndication.device.nut"

// Duration of a signal, in seconds
const LI_SIGNAL_DURATION = 1.0;
// Duration of a gap (delay) between signals, in seconds
const LI_GAP_DURATION = 0.2;

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

                    // Make a gap (delay) between signals for better perception
                    imp.wakeup(LI_GAP_DURATION, resolve);
                }.bindenv(this);

                // Turn off all colors after the signal duration
                imp.wakeup(LI_SIGNAL_DURATION, stop);
            }.bindenv(this));
        }.bindenv(this));
    }
}

//line 28 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/Main.device.nut"

//line 1 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/Hardware.device.nut"
// Temperature-humidity sensor's I2C bus
// NOTE: This I2C bus is used by the accelerometer as well. And it's configured by the accelerometer
HW_TEMPHUM_SENSOR_I2C <- hardware.i2cLM;
// Accelerometer's I2C bus
// NOTE: This I2C bus is used by the temperature-humidity sensor as well. But it's configured by the accelerometer
HW_ACCEL_I2C <- hardware.i2cLM;
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
//line 2 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/ProductionManager.device.nut"

// ProductionManager's user config field
const PMGR_USER_CONFIG_FIELD = "ProductionManager";
// Period (sec) of checking for new deployments
const PMGR_CHECK_UPDATES_PERIOD = 10;
// Maximum length of stats arrays
const PMGR_STATS_MAX_LEN = 10;
// Maximum length of error saved when error flag is set
const PMGR_MAX_ERROR_LEN = 512;
// Connection timeout (sec)
const PMGR_CONNECT_TIMEOUT = 240;

// Implements useful in production features:
// - Emergency mode (If an unhandled error occurred, device goes to sleep and periodically connects to the server waiting for a SW update)
// - Shipping mode (When released from the factory, the device sleeps until it is woken up by the end-user) (NOT IMPLEMENTED)
class ProductionManager {
    _debugOn = false;
    _startAppFunc = null;

    /**
     * Constructor for Production Manager
     *
     * @param {function} startAppFunc - The function to be called to start the main application
     */
    constructor(startAppFunc) {
        _startAppFunc = startAppFunc;
    }

    /**
     * Start the manager. It will check the conditions and either start the main application or go to sleep
     */
    function start() {
        // TODO: Erase the flash memory on first start (when awake from shipping mode)? Or in factory code?

        // NOTE: The app may override this handler but it must call enterEmergencyMode in case of a runtime error
        imp.onunhandledexception(_onUnhandledException.bindenv(this));

        local userConf = _readUserConf();
        local data = _extractDataFromUserConf(userConf);

        if (data == null) {
            _startAppFunc();
            return;
        }

        if (data.lastError != null) {
            // TODO: Improve logging!
            _printLastError(data.lastError);
        }

        if (data.errorFlag && data.deploymentID == __EI.DEPLOYMENT_ID) {
            if (server.isconnected()) {
                // No new deployment was detected
                _sleep();
            } else {
                // Connect to check for a new deployment
                server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 30);
                server.connect(_sleep.bindenv(this), PMGR_CONNECT_TIMEOUT);
            }
            return;
        } else if (data.deploymentID != __EI.DEPLOYMENT_ID) {
            _info("New deployment detected!");
            userConf[PMGR_USER_CONFIG_FIELD] <- _initialUserConfData();
            _storeUserConf(userConf);
        }

        _startAppFunc();
    }

    /**
     * Manually enter the Emergency mode
     *
     * @param {string} [error] - The error that caused entering the Emergency mode
     */
    function enterEmergencyMode(error = null) {
        _setErrorFlag(error);
        server.restart();
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
     * Print the last saved error
     *
     * @param {table} lastError - Last saved error with timestamp and description
     */
    function _printLastError(lastError) {
        if ("ts" in lastError && "desc" in lastError) {
            _info(format("Last error (at %d): \"%s\"", lastError.ts, lastError.desc));
        }
    }

    /**
     * Go to sleep once Squirrel VM is idle
     */
    function _sleep(unusedParam = null) {
        imp.onidle(function() {
            server.sleepfor(PMGR_CHECK_UPDATES_PERIOD);
        });
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
     * @return {table} The initial user configuration data
     */
    function _initialUserConfData() {
        return {
            "errorFlag": false,
            "lastError": null,
            "deploymentID": __EI.DEPLOYMENT_ID
        };
    }

    /**
     * Set the error flag which will restrict running the main application on the next boot
     *
     * @param {string} error - The error description
     */
    function _setErrorFlag(error) {
        local userConf = _readUserConf();
        // If not null, this is just a pointer to the field of userConf. Hence modification of this object updates the userConf object
        local data = _extractDataFromUserConf(userConf);

        if (data == null) {
            // Initialize ProductionManager's user config data
            data = _initialUserConfData();
            userConf[PMGR_USER_CONFIG_FIELD] <- data;
        }

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

        _storeUserConf(userConf);
    }

    /**
     * Store the user configuration
     *
     * @param {table} userConf - The table to be converted to JSON and stored
     */
    function _storeUserConf(userConf) {
        local dataStr = JSONEncoder.encode(userConf);
        _debug("Storing new user configuration: " + dataStr);

        try {
            imp.setuserconfiguration(dataStr);
        } catch (err) {
            _error(err);
        }
    }

    /**
     * Read the user configuration
     *
     * @return {table} The user configuration converted from JSON to a Squirrel table
     */
    function _readUserConf() {
        local config = imp.getuserconfiguration();

        if (config == null) {
            _debug("User configuration is empty");
            return {};
        }

        config = config.tostring();
        // TODO: What if a non-readable string was written? It will be printed "binary: ..."
        _debug("User configuration: " + config);

        try {
            config = JSONParser.parse(config);

            if (typeof config != "table") {
                throw "table expected";
            }
        } catch (e) {
            _error("Error during parsing user configuration: " + e);
            return {};
        }

        return config;
    }

    /**
     * Extract and check the data belonging to Production Manager from the user configuration
     *
     * @param {table} userConf - The user configuration
     *
     * @return {table|null} The data extracted or null
     */
    function _extractDataFromUserConf(userConf) {
        try {
            local data = userConf[PMGR_USER_CONFIG_FIELD];

            if ("errorFlag" in data &&
                "lastError" in data &&
                "deploymentID" in data) {
                return data;
            }
        } catch (err) {
        }

        return null;
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

//line 1 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/Configuration.device.nut"
// Configuration settings for imp-device

// Data reading period, in seconds
const DEFAULT_DATA_READING_PERIOD = 20.0;

// Data sending period, in seconds
const DEFAULT_DATA_SENDING_PERIOD = 60.0;

// Alert settings:

// Temperature high alert threshold, in Celsius
const DEFAULT_TEMPERATURE_HIGH =  25.0;
// Temperature low alert threshold, in Celsius
const DEFAULT_TEMPERATURE_LOW = 10.0;

// Battery low alert threshold, in %
const DEFAULT_BATTERY_LOW = 7.0; // not supported

// Shock acceleration alert threshold, in g
// IMPORTANT: This value affects the measurement range and accuracy of the accelerometer:
// the larger the range - the lower the accuracy.
// This can affect the effectiveness of the MOVEMENT_ACCELERATION_MIN constant.
// For example: if SHOCK_THRESHOLD > 4.0 g, then MOVEMENT_ACCELERATION_MIN should be > 0.1 g
const DEFAULT_SHOCK_THRESHOLD = 8.0;

// Location tracking settings:

// Location reading period, in seconds
const DEFAULT_LOCATION_READING_PERIOD = 180.0;

// Motion start detection settings:

// Movement acceleration threshold range [min..max]:
// - minimum (starting) level, in g
const DEFAULT_MOVEMENT_ACCELERATION_MIN = 0.2;
// - maximum level, in g
const DEFAULT_MOVEMENT_ACCELERATION_MAX = 0.4;
// Duration of exceeding movement acceleration threshold, in seconds
const DEFAULT_MOVEMENT_ACCELERATION_DURATION = 0.25;
// Maximum time to determine motion detection after the initial movement, in seconds
const DEFAULT_MOTION_TIME = 15.0;
// Minimum instantaneous velocity to determine motion detection condition, in meters per second
const DEFAULT_MOTION_VELOCITY = 0.5;
// Minimal movement distance to determine motion detection condition, in meters.
// If 0, distance is not calculated (not used for motion detection)
const DEFAULT_MOTION_DISTANCE = 5.0;

// BLE devices and their locations
DEFAULT_BLE_DEVICES <- {
    // This key may contain an empty table but it must be present
    "generic": {
        "656684e1b306": {
            "lat": 1,
            "lng": 2
        }
    },
    // This key may contain an empty table but it must be present
    "iBeacon": {
        "\x01\x12\x23\x34\x45\x56\x67\x78\x89\x9a\xab\xbc\xcd\xde\xef\xf0": {
            [1800] = {
                [1286] = { "lat": 10, "lng": 20 }
            }
        }
    }
};
//line 2 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/CustomConnectionManager.device.nut"

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

        // TODO: Add periodic connection?
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
     * May be called when connectected and when disconnected as well
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

//line 2 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/CustomReplayMessenger.device.nut"

// Customized ReplayMessenger library

// Maximum number of recent messages to look into when searching the maximum message ID
const CRM_MAX_ID_SEARCH_DEPTH = 20;
// Minimum free memory (bytes) to allow SPI flash logger reading and resending persisted messages
const CRM_FREE_MEM_THRESHOLD = 81920;
// Custom value for MSGR_QUEUE_CHECK_INTERVAL_SEC
const CRM_QUEUE_CHECK_INTERVAL_SEC = 1.0;
// Custom value for RM_RESEND_RATE_LIMIT_PCT
const CRM_RESEND_RATE_LIMIT_PCT = 80;

class CustomReplayMessenger extends ReplayMessenger {
    _persistedMessagesPending = false;
    _eraseAllPending = false;
    _onIdleCb = null;
    _onAckCbs = null;
    _onAckDefaultCb = null;
    _onFailCbs = null;
    _onFailDefaultCb = null;

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

    function onAck(cb, name = null) {
        if (name == null) {
            _onAckDefaultCb = cb;
        } else if (cb) {
            _onAckCbs[name] <- cb;
        } else if (name in _onAckCbs) {
            delete _onAckCbs[name];
        }
    }

    function onFail(cb, name = null) {
        if (name == null) {
            _onFailDefaultCb = cb;
        } else if (cb) {
            _onFailCbs[name] <- cb;
        } else if (name in _onFailCbs) {
            delete _onFailCbs[name];
        }
    }

    function readyToSend() {
        return _cm.isConnected() && _checkSendLimits();
    }

    function hasPersistedMessages() {
        return _persistedMessagesPending;
    }

    function isIdle() {
        return _isAllProcessed();
    }

    // Registers a callback which will be called when _isAllProcessed() turns false
    function onIdle(cb) {
        _onIdleCb = cb;
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
            _onIdleCb && _onIdleCb();
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

//line 1 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/bg96_gps.device.lib.nut"
/*
 * BG96_GPS library
 * Copyright 2020 Twilio
 *
 * MIT License
 * SPDX-License-Identifier: MIT
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:

 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.

 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
 * EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
 * OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */


/*
 * Enums
 */
enum BG96_ERROR_CODE {
    IMPOS_TIMEOUT                   = "-1",
    IMPOS_MODEM_NOT_READY           = "-2",
    IMPOS_MODEM_IS_BUSY             = "-3",
    IMPOS_INVALID_PARAM             = "-4",
    IMPOS_TRANSMISSION_FAIL         = "-5",
    FILE_INVALID_INPUT              = "400",
    FILE_SIZE_MISMATCH              = "401",
    FILE_READ_ZERO_BYTE             = "402",
    FILE_DRIVE_FULL                 = "403",
    FILE_NOT_FOUND                  = "405",
    FILE_INVALID_NAME               = "406",
    FILE_ALREADY_EXISTS             = "407",
    FILE_WRITE_FAIL                 = "409",
    FILE_OPEN_FAIL                  = "410",
    FILE_READ_FAIL                  = "411",
    FILE_MAX_OPEN_FILES             = "413",
    FILE_READ_ONLY                  = "414",
    FILE_INVALID_DESCRIPTOR         = "416",
    FILE_LIST_FAIL                  = "417",
    FILE_DELETE_FAIL                = "418",
    FILE_GET_DISK_INFO_FAIL         = "419",
    FILE_NO_SPACE                   = "420",
    FILE_TIMEOUT                    = "421",
    FILE_TOO_LARGE                  = "423",
    FILE_INVALID_PARAM              = "425",
    FILE_ALREADY_OPEN               = "426",
    GPS_INVALID_PARAM               = "501",
    GPS_OPERATION_NOT_SUPPORTED     = "502",
    GPS_GNSS_SUBSYSTEM_BUSY         = "503",
    GPS_SESSION_IS_ONGOING          = "504",
    GPS_SESSION_NOT_ACTIVE          = "505",
    GPS_OPERATION_TIMEOUT           = "506",
    GPS_FUNCTION_NOT_ENABLED        = "507",
    GPS_TIME_INFO_ERROR             = "508",
    GPS_XTRA_NOT_ENABLED            = "509",
    GPS_VALIDITY_TIME_OUT_OF_RANGE  = "512",
    GPS_INTERNAL_RESOURCE_ERROR     = "513",
    GPS_GNSS_LOCKED                 = "514",
    GPS_END_BY_E911                 = "515",
    GPS_NO_FIX_NOW                  = "516",
    GPS_GEO_FENCE_ID_DOES_NOT_EXIST = "517",
    GPS_UNKNOWN_ERROR               = "549"
}

enum BG96_GNSS_ON_DEFAULT {
    MODE                = 1,    // Stand Alone is the only mode supported (1)
    MAX_POS_TIME_SEC    = 30,   // Sec max pos time (30)
    FIX_ACCURACY_METERS = 50,   // Fix accuracy in meters (50)
    NUM_FIX_CHECKS      = 0,    // Num of checks after fix before powering down GPS (0 - continuous)
    GET_LOC_FREQ_SEC    = 1,    // Check every x sec (1)
    RETRY_TIME_SEC      = 1,    // Time to wait for modem to power up
}

enum BG96_GNSS_LOCATION_MODE {
    ZERO,   // <latitude>,<longitude> format: ddmm.mmmm N/S,dddmm.mmmm E/W
    ONE,    // <latitude>,<longitude> format: ddmm.mmmmmm,N/S,dddmm.mmmmmm,E/W
    TWO     // <latitude>,<longitude> format: (-)dd.ddddd,(-)ddd.ddddd
}

// Stale location data is often returned immediately after power up
const BG96_GPS_EN_POLLING_TIMEOUT = 3;
// Duration (sec) of enabling the assist function of BG96
const BG96_ASSIST_ENABLE_DURATION = 0.5;
// Duration (sec) of loading fresh assist data into BG96
const BG96_ASSIST_LOAD_DURATION = 2.0;

/*
 * Library
 */
BG96_GPS <- {

    VERSION   = "0.1.5_alert_custom_0.1.1",

    /*
     * PRIVATE PROPERTIES
     */
     _locTimer = null,
    _session   = null,
    _minSuppportedImpOS = 43.0,
    _impOSVersion = null,
    _pollTimer = null,

    /*
     * PUBLIC FUNCTIONS
     */
    isGNSSEnabled = function() {
        _checkOS();

        if (_session == null) return false;

        try {
            local resp = _session.getstate();
            return (resp.state == 1);
        } catch(e) {
            _log(e);
        }
    },

    enableGNSS = function(opts = {}) {
        _checkOS();
        local gnssMode   = ("gnssMode" in opts)   ? opts.gnssMode   : BG96_GNSS_ON_DEFAULT.MODE;
        local posTime    = ("maxPosTime" in opts) ? opts.maxPosTime : BG96_GNSS_ON_DEFAULT.MAX_POS_TIME_SEC;
        local accuracy   = ("accuracy" in opts)   ? opts.accuracy   : BG96_GNSS_ON_DEFAULT.FIX_ACCURACY_METERS;
        local numFixes   = ("numFixes" in opts)   ? opts.numFixes   : BG96_GNSS_ON_DEFAULT.NUM_FIX_CHECKS;
        local checkFreq  = ("checkFreq" in opts)  ? opts.checkFreq  : BG96_GNSS_ON_DEFAULT.GET_LOC_FREQ_SEC;
        local retryTime  = ("retryTime" in opts)  ? opts.retryTime  : BG96_GNSS_ON_DEFAULT.RETRY_TIME_SEC;
        local locMode    = ("locMode" in opts)    ? opts.locMode    : BG96_GNSS_LOCATION_MODE.TWO;
        local onEnabled  = ("onEnabled" in opts && typeof opts.onEnabled == "function")   ? opts.onEnabled  : null;
        local onLocation = ("onLocation" in opts && typeof opts.onLocation == "function") ? opts.onLocation : null;
        local assistData = ("assistData" in opts) ? opts.assistData : null;
        local useAssist  = ("useAssist" in opts) ? opts.useAssist : false;

        if (!isGNSSEnabled()) {
            if (_session == null) {
                try {
                    local wasReady = false;

                    _session = hardware.gnss.open(function(t) {
                        _log("Session is " + (t.ready == 0 ? "not ready" : "ready"));
                        if (!wasReady && t.ready == 1) {
                            wasReady = true;
                            enableGNSS(opts);
                        }
                    }.bindenv(this));
                } catch (err) {
                    _log("Exception was thrown by hardware.gnss.open(): " + err, true);
                    onEnabled && onEnabled(err);
                }

                return;
            }

            if (assistData) {
                try {
                    _session.assist.load(function(t) {
                        _log("Assist data " + (t.status == 0 ? "loaded" : "not loaded"));
                        if (t.status != 0 && "message" in t) _log("Error: " + t.message, true);
                        if ("restart" in t) _log("Modem restarted? " + (t.restart == 0 ? "No" : "Yes"));

                        // To let the new assist data be applied, we immediately enable the assist function
                        try {
                            _session.assist.enable();
                        } catch (err) {
                            // If there is an exception, we just disable assist to not run into an infinite loop
                            opts.useAssist <- false;
                            opts.assistData = null;
                            _log("Exception was thrown by session.assist.enable(): " + err, true);
                            enableGNSS(opts);
                            return;
                        }
                        // Sleep to let the opration be finished
                        imp.sleep(BG96_ASSIST_LOAD_DURATION);

                        opts.assistData = null;
                        if (!("useAssist" in opts)) opts.useAssist <- true;
                        enableGNSS(opts);
                    }.bindenv(this), assistData);
                } catch (err) {
                    _log("Exception was thrown by session.assist.load(): " + err, true);
                }

                return;
            }

            if (useAssist) {
                // FROM 0.1.5 -- check we have assist data before proceeding
                // This will be the case if 'enableGNSS()' called with 'useAssist' set true,
                // but 'assistData' is null or passed bad data
                if (isAssistDataValid().valid) {
                    // There is assist data present, so proceed to enable
                    local res = null;
                    try {
                        res = _session.assist.enable();
                    } catch (err) {
                        _log("Exception was thrown by session.assist.enable(): " + err, true);
                    }

                    if (res != null) {
                        // Sleep to let the opration be finished. Otherwise, session.assist.read() will return zero/empty data
                        // TODO: Not sure if this is enough to get valid info..
                        imp.sleep(BG96_ASSIST_ENABLE_DURATION);
                        _log("Assist " + (res.status == 0 ? "enabled" : "not enabled"));
                    }
                } else {
                    _log("Assist data not present or overdue -- cannot enable Assist", true);
                }
            }

            local resp = null;
            try {
                resp = _session.enable(gnssMode, posTime, accuracy, numFixes, checkFreq);
            } catch (err) {
                _log("Exception was thrown by session.enable(): " + err, true);
                onEnabled && onEnabled(err);
                return;
            }

            if (resp.status != 0) {
                local status = resp.status.tostring();
                if (status != BG96_ERROR_CODE.GPS_SESSION_IS_ONGOING) {
                    _log("Error enabling GNSS: " + resp.status, true);
                    onEnabled && onEnabled("Error enabling GNSS: " + resp.status);
                    return;
                }
                imp.wakeup(retryTime, function() {
                    enableGNSS(opts);
                }.bindenv(this))
            } else {
                onEnabled && onEnabled(null);
                if (onLocation != null) {
                    // If there is no delay returns stale loc on first 2 (1sec) requests
                    if (_pollTimer != null) imp.cancelwakeup(_pollTimer);
                    _pollTimer = imp.wakeup(BG96_GPS_EN_POLLING_TIMEOUT, function() {
                        _pollLoc(locMode, checkFreq, onLocation, posTime - BG96_GPS_EN_POLLING_TIMEOUT);
                    }.bindenv(this));
                }
            }
        } else {
            // TODO: Assist data is not loaded if already enabled
            _log("Already enabled");
            onEnabled && onEnabled(null);
            if (onLocation != null) {
                if (_pollTimer != null) imp.cancelwakeup(_pollTimer);
                _pollTimer = imp.wakeup(BG96_GPS_EN_POLLING_TIMEOUT, function() {
                    _pollLoc(locMode, checkFreq, onLocation, posTime - BG96_GPS_EN_POLLING_TIMEOUT);
                }.bindenv(this));
            }
        }
    },

    // NOTE Cancels _poll location timer if running
    disableGNSS = function() {
        _checkOS();

        // Always cancel location timer
        _cancelLocTimer();
        if (_pollTimer != null) imp.cancelwakeup(_pollTimer);

        if (isGNSSEnabled()) {
            local resp = null;
            try {
                resp = _session.disable();
            } catch (err) {
                _log("Exception was thrown by session.disable(): " + err, true);
                return false;
            }

            if (resp.status != 0) {
                _log("Error disabling GNSS: " + resp.error);
                return false;
            } else {
                _log("Disabled");
            }
        }

        _session = null;
        return true;
    },

    getLocation = function(opts = {}) {
        _checkOS();

        local poll       = ("poll" in opts) ? opts.poll : false;
        local mode       = ("mode" in opts) ? opts.mode : BG96_GNSS_LOCATION_MODE.ZERO;
        local checkFreq  = ("checkFreq" in opts) ? opts.checkFreq : BG96_GNSS_ON_DEFAULT.GET_LOC_FREQ_SEC;
        local onLocation = ("onLocation" in opts && typeof opts.onLocation == "function") ? opts.onLocation : null;

        // If we have no callback just return an error
        if (onLocation == null) {
            return { "error" : "onLocation callback required" };
        }

        if (poll) {
            _pollLoc(mode, checkFreq, onLocation);
        } else {
            _getLoc(mode, function(loc) {
                if (loc == null) loc = { "error" : "GPS fix not available" };
                onLocation(loc);
            });
        }
    },

    // Is the assist data good?
    isAssistDataValid = function() {
        _checkOS();

        local t = null;
        try {
            t = _session.assist.read();
        } catch (err) {
            _log("Exception was thrown by session.assist.read(): " + err, true);
            return {"valid": false};
        }

        if (t.status == 0) {
            local validTime = _getValidTime(t.injecteddatatime, t.xtradatadurtime);
            _log("Assist data is valid for " + validTime + " minutes");
            _log("Assist data became valid on " + t.injecteddatatime);

            return {
                "valid": validTime > 0,
                "time": validTime
            }
        }

        return {"valid": false};
    },

    // Delete any existing assist data
    // ***** UNTESTED *****
    deleteAssistData = function(mode = 3) {
        _checkOS();

        if (isGNSSEnabled()) {
            // GNSS enabled, so disable before deleting
            local resp = null;
            try {
                resp = _session.disable();
            } catch (err) {
                _log("Exception was thrown by session.disable(): " + err, true);
                return;
            }

            if (resp.status != 0) {
                _log(format("Error disabling GNSS: %i -- could not delete assist data" resp.error), true);
            } else {
                // GNSS now disabled, so we can proceed with deletion
                _deleteAssist(mode);
            }
        } else {
            if (_session == null) {
                // We have to make a session in order to delete the assist data
                try {
                    _session = hardware.gnss.open(function(t) {
                        if (t.ready == 1) _deleteAssist(mode);
                    }.bindenv(this));
                } catch (err) {
                    _log("Exception was thrown by hardware.gnss.open(): " + err, true);
                }
            } else {
                _deleteAssist(mode);
            }
        }
    },

    /*
     * PRIVATE FUNCTIONS -- DO NOT CALL DIRECTLY
     */

    // Loop that polls for location, if location data or error (excluding no fix available) is received it is
    // passed to the onLoc callback
    _pollLoc = function(mode, checkFreq, onLoc, timeout = null) {
        // Only allow one schedule timer at a time
        _cancelLocTimer();

        if (timeout != null) {
            if (timeout <= 0) {
                imp.wakeup(0, function() { onLoc({"error": "Positioning timeout"}); }.bindenv(this));
                return;
            }

            timeout -= checkFreq;
        }

        // Schedule next location check
        _locTimer = imp.wakeup(checkFreq, function() {
            _pollLoc(mode, checkFreq, onLoc, timeout);
        }.bindenv(this));

        // Fetch and process location
        // Returns `null` if GPS error is no fix now, otherwise returns table with keys fix or error
        _getLoc(mode, function(loc) {
            if (loc != null) {
                // Pass error or location fix to main application
                imp.wakeup(0, function() { onLoc(loc); }.bindenv(this));
            }
        });
    },

    // Sends AT command to get location, mode parameter sets the data lat/lng data format
    // Calls back with null if no fix is available or the response as a table that may contain slots:
        // error (string): The error encountered
        // fix (table/string): response data string if location parsing failed otherwise a table with
        // slots: cog, alt, fixType, time, numSats, lat, lon, spkm, spkn, utc, data, hdop
    _getLoc = function(mode, cb) {
        try {
            _session.readposition(function(resp) {
                local data = {};
                if (resp.status != 0) {
                    // Look for expected errors
                    local errorCode = resp.status.tostring();
                    switch (errorCode) {
                        case BG96_ERROR_CODE.GPS_NO_FIX_NOW:
                            _log("GPS fix not available");
                            return cb(null);
                        case BG96_ERROR_CODE.GPS_SESSION_NOT_ACTIVE:
                            _log("GPS not enabled.");
                            data.error <- "GPS not enabled";
                            return cb(data);
                        case BG96_ERROR_CODE.IMPOS_TIMEOUT:
                        case BG96_ERROR_CODE.IMPOS_MODEM_NOT_READY:
                        case BG96_ERROR_CODE.IMPOS_MODEM_IS_BUSY:
                            _log("Trying getting location again...");
                            return cb(null);
                        default:
                            _log("GPS location request failed with error: " + errorCode);
                            data.error <- "Error code: " + errorCode;
                            return cb(data);
                    }
                }

                if (resp.status == 0 && "quectel" in resp) {
                    data.fix <- _parseLocData(resp.quectel, mode);
                }

                cb(data);
            }.bindenv(this), mode);
        } catch (err) {
            _log("Exception was thrown by session.readposition(): " + err, true);
            cb(null);
        }
    },

    // Cancels location polling timer
    _cancelLocTimer = function() {
        if (_locTimer != null) {
            imp.cancelwakeup(_locTimer);
            _locTimer = null;
        }
    },

    // Format GPS timestamp
    _formatTimeStamp = function(d, utc) {
        // Input d: DDMMYY, utc HHMMSS.S
        // Formatted result: YYYY/MM/DD,hh:mm:ss
        return format("20%s/%s/%s,%s:%s:%s", d.slice(4),
                                             d.slice(2, 4),
                                             d.slice(0, 2),
                                             utc.slice(0, 2),
                                             utc.slice(2, 4),
                                             utc.slice(4));
    },

    // Parses location data into table based on mode
    _parseLocData = function(parsed, mode) {
        _log("Parsing location data");
        try {
            switch(mode) {
                case BG96_GNSS_LOCATION_MODE.ZERO:
                    // 190629.0,3723.7238N,12206.1395W,1.0,16.0,2,188.18,0.0,0.0,031219,09
                case BG96_GNSS_LOCATION_MODE.TWO:
                    // 190629.0,37.39540,-122.10232,1.0,16.0,2,188.18,0.0,0.0,031219,09
                case BG96_GNSS_LOCATION_MODE.ONE:
                    // 190629.0,3723.723831,N,12206.139526,W,1.0,16.0,2,188.18,0.0,0.0,031219,09
                     return {
                        "utc"     : parsed.utc,
                        "lat"     : parsed.latitude,
                        "lon"     : parsed.longitude,
                        "hdop"    : parsed.hdop,
                        "alt"     : parsed.altitude,
                        "fixType" : parsed.fix,
                        "cog"     : parsed.cog,
                        "spkm"    : parsed.spkm,
                        "spkn"    : parsed.spkn,
                        "date"    : parsed.date,
                        "numSats" : parsed.nsat,
                        "time"    : _dateToTimestamp(_formatTimeStamp(parsed.date, parsed.utc))
                    };
                default:
                    throw "Unknown mode";
            }
        } catch(ex) {
            _log("Error parsing GPS data " + ex);
            return parsed;
        }
    },

    _log = function(msg, isError = false) {
        if (isError) {
            ::error(msg, "BG96_GPS");
        } else {
            ::debug(msg, "BG96_GPS");
        }
    },

    // Check we're running on a correct system
    _checkOS = function() {
        if (_impOSVersion == null) {
            local n = split(imp.getsoftwareversion(), "-");
            _impOSVersion = n[2].tofloat();
        }

        try {
            assert(_impOSVersion >= _minSuppportedImpOS);
        } catch (exp) {
            throw "BG96_GPS 0.1.0 requires impOS 43 or above";
        }
    },

    // FROM 0.1.5
    // Get assist data remaining validity period in mins
    // 'uploadDate' is a string of format: YYYY/MM/DD,hh:mm:ss
    _getValidTime = function(uploadDate, duration) {
        local uploadTs = _dateToTimestamp(uploadDate);
        local timeRemaining = duration - (time() - uploadTs) / 60;
        return timeRemaining > 0 ? timeRemaining : 0;
    },

    // date is a string of format: YYYY/MM/DD,hh:mm:ss
    _dateToTimestamp = function(date) {
        try {
            date = split(date, ",");
            date[0] = split(date[0], "/");
            date[1] = split(date[1], ":");

            local y = date[0][0].tointeger();
            local m = date[0][1].tointeger();
            local d = date[0][2].tointeger();
            local hrs = date[1][0].tointeger();
            local min = date[1][1].tointeger();
            local sec = date[1][2].tointeger();
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
            _log("Couldn't parse the date: " + err, true);
            return 0;
        }
    },

    // FROM 0.1.5
    _deleteAssist = function(mode) {
        local res = null;
        try {
            res = _session.assist.reset(mode);
        } catch (err) {
            _log("Exception was thrown by session.assist.reset(): " + err, true);
            return;
        }

        if (res.status == 0) {
            _log("Assist data deleted");
        } else {
            local err = format("[BG96_GPS] Could not delete assist data (status %i)", res.status);
            _log(err, true);
        }
    }
}
//line 2 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/BG96CellInfo.device.nut"

// Required BG96 AT Commands
enum AT_COMMAND {
    // Query the information of neighbour cells (Detailed information of base station)
    GET_QENG  = "AT+QENG=\"neighbourcell\"",
    // Query the information of serving cell (Detailed information of base station)
    GET_QENG_SERV_CELL  = "AT+QENG=\"servingcell\""
}

// Class to obtain cell towers info from BG96 modem.
// This code uses unofficial impOS features
// and is based on an unofficial example provided by Twilio
// Utilizes the following AT Commands:
// - Network Service Commands:
//   - AT+CREG Network Registration Status
//   - AT+COPS Operator Selection
// - QuecCell Commands:
//   - AT+QENG Switch on/off Engineering Mode
class BG96CellInfo {

    /**
    * Get the network registration information from BG96
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

        try {
            local qengCmdResp = _writeAndParseAT(AT_COMMAND.GET_QENG_SERV_CELL);
            if ("error" in qengCmdResp) {
                throw "AT+QENG serving cell command returned error: " + qengCmdResp.error;
            }

            local srvCellRadioType = _qengExtractRadioType(qengCmdResp.data);

            switch (srvCellRadioType) {
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
                        ::error("AT+QENG command returned error: " + qengCmdResp.error, "BG96CellInfo");
                    } else {
                        data.cellTowers.extend(_qengExtractTowersInfo(qengCmdResp.data, srvCellRadioType));
                    }
                    break;
                case "CAT-M":
                case "CAT-NB":
                case "LTE":
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
                    // https://developers.google.com/maps/documentation/geolocation/overview#wifi_access_point_object
                    // location is determined by one tower
                    break;
                default:
                    throw "Unknown radio type: " + srvCellRadioType;
            }
        } catch (err) {
            ::error("Scanning cell towers error: " + err, "BG96CellInfo");
            return null;
        }

        return data;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Send the specified AT Command, parse a response.
     * Return table with the parsed response.
     */
    function _writeAndParseAT(cmd) {
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
     * Send the specified AT Command to BG96.
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
            local lac = splitted[12];
            local ci = splitted[6];
            local ss = splitted[15];
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
}

//line 2 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/ESP32Driver.device.nut"

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
const ESP32_MAX_DATA_LEN = 12288;
// Automatic switch off delay, in seconds
const ESP32_SWITCH_OFF_DELAY = 10;

// TODO: Tune the following 3 constants. Sometimes it can scan not all devices
//       But we also should avoid OOM (please, see the TODO above _waitForData())
// Scan interval. It should be more than or equal to the value of <scan_window>.
// The range of this parameter is [0x0004,0x4000].
// The scan interval equals this parameter multiplied by 0.625 ms,
// so the range for the actual scan interval is [2.5,10240] ms.
const ESP32_BLE_SCAN_INTERVAL = 8;
// Scan window. It should be less than or equal to the value of <scan_interval>.
// The range of this parameter is [0x0004,0x4000].
// The scan window equals this parameter multiplied by 0.625 ms,
// so the range for the actual scan window is [2.5,10240] ms.
const ESP32_BLE_SCAN_WINDOW = 8;
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
     * An exception will be thrown in case of settings or UART configuration error.
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

            local okValidator = @(data, _) data.find("\r\nOK\r\n") != null;
            // Send "List Available APs" cmd and parse the result
            return _communicate("AT+CWLAP", okValidator, _parseWifiNetworks, false);
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
            local validator = @(data, timeElapsed) (data.find("\r\nOK\r\n") != null &&
                                                    timeElapsed >= ESP32_BLE_SCAN_PERIOD);
            // Send "Enable Bluetooth LE Scanning" cmd and parse the result
            return _communicate(bleScanCmd, validator, _parseBLEAdverts, false);
        }.bindenv(this))
        .then(function(adverts) {
            ::debug("Scanning of BLE advertisements finished successfully. Scanned items: " + adverts.len(), "ESP32Driver");
            _switchOffTimer = imp.wakeup(ESP32_SWITCH_OFF_DELAY, _switchOff.bindenv(this));
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
        local restoreCmdValidator = @(data, _) data.find("\r\nOK\r\n\r\nready\r\n") != null;
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
            _communicate("AT+RESTORE", restoreCmdValidator),
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
     *                                       This optionis useful for, e.g., serial execution of a list of promises (Promise.serial)
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
        _switchPin.disable();
        _serial.disable();
        _switchedOn = false;
        _initialized = false;

        ::debug("ESP32 board has been switched OFF", "ESP32Driver");
    }

    /**
     * Parse the data returned by the AT+CWLAP (List Available APs) command
     *
     * @param {string} data - String with a reply to the AT+CWLAP command
     *
     * @return {array} of parsed WiFi networks
     *  Each element of the array is a table with the following fields:
     *     "ssid"      : {string}  - SSID (network name).
     *     "bssid"     : {string}  - BSSID (access point’s MAC address), in 0123456789ab format.
     *     "channel"   : {integer} - Channel number: 1-13 (2.4GHz).
     *     "rssi"      : {integer} - RSSI (signal strength).
     *     "open"      : {bool}    - Whether the network is open (password-free).
     * An exception may be thrown in case of an error.
     */
    function _parseWifiNetworks(data) {
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
            local wifis = [];
            local dataRows = split(data, "\r\n");

            foreach (row in dataRows) {
                local regexCapture = regex.capture(row);

                if (regexCapture == null) {
                    continue;
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

                wifis.push(scannedWifi);
            }

            return wifis;
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
     * @param {function} validator - Function that checks if the expected data has been fully received
     *
     * @return {Promise} that:
     * - resolves with the data received if the operation succeeded
     * - rejects if the operation failed
     */
    // TODO: On-the-fly data processing may be required. And memory consumption optimization.
    //       If we wait for all data to be received before processing, we can face OOM due to the need of keeping all raw recevied data
    function _waitForData(validator) {
        // Data check/read period, in seconds
        const ESP32_DATA_CHECK_PERIOD = 0.1;
        // Maximum data length expected to be received from ESP32, in bytes
        const ESP32_DATA_READ_CHUNK_LEN = 1024;

        local start = hardware.millis();
        local data = "";

        return Promise(function(resolve, reject) {
            local check;
            check = function() {
                local chunk = _serial.readblob(ESP32_DATA_READ_CHUNK_LEN);

                // Read until FIFO is empty and accumulate to the result string
                while (chunk.len() > 0 && data.len() < ESP32_MAX_DATA_LEN) {
                    data += chunk.tostring();
                    chunk = _serial.readblob(ESP32_DATA_READ_CHUNK_LEN);
                }

                local timeElapsed = (hardware.millis() - start) / 1000.0;

                if (validator(data, timeElapsed)) {
                    return resolve(data);
                }

                if (timeElapsed >= ESP32_WAIT_DATA_TIMEOUT) {
                    return reject("Timeout waiting for the expected data or an acknowledge");
                }

                if (data.len() >= ESP32_MAX_DATA_LEN) {
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
     * @param {string} data - String with a reply to the AT+BLESCAN command
     *
     * @return {array} of scanned BLE advertisements
     *  Each element of the array is a table with the following fields:
     *     "address"  : {string}  - BLE address.
     *     "rssi"     : {integer} - RSSI (signal strength).
     *     "advData"  : {blob} - Advertising data.
     *     "addrType" : {integer} - Address type: 0 - public, 1 - random.
     * An exception may be thrown in case of an error.
     */
    function _parseBLEAdverts(data) {
        // The data should look like the following:
        // AT+BLESCAN=1,5
        // OK
        // +BLESCAN:6f:92:8a:04:e1:79,-89,1aff4c000215646be3e46e4e4e25ad0177a28f3df4bd00000000bf,,1
        // +BLESCAN:76:72:c3:3e:29:e4,-79,1bffffffbeac726addafa7044528b00b12f8f57e7d8200000000bb00,,1

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
            // Result array of scanned advertisements
            local result = [];
            // Array of strings to be compared to check the uniqueness of an advertisement
            local uniqueAdverts = [];
            local dataRows = split(data, "\r\n");

            // In order to process fresher advertisements first (to get the latest RSSI for duplicated adverts), reverse this array
            dataRows.reverse();

            foreach (row in dataRows) {
                local regexCapture = regex.capture(row);

                if (regexCapture == null) {
                    continue;
                }

                // The first capture is the full row. Let's remove it as we only need the parsed pieces of the row
                regexCapture.remove(0);
                // Convert the array of begin/end indexes to an array of substrings parsed out from the row
                foreach (i, val in regexCapture) {
                    regexCapture[i] = row.slice(val.begin, val.end);
                }

                local address = _removeColon(regexCapture[ESP32_BLE_PARAM_ORDER.ADDR]);
                local advData = regexCapture[ESP32_BLE_PARAM_ORDER.ADV_DATA];
                local addrType = regexCapture[ESP32_BLE_PARAM_ORDER.ADDR_TYPE].tointeger();

                // Make a string that helps to compare adverts.
                // Advertisement uniqueness is determined by equality of address, advData and addrType
                local stringAdvert = address + advData + addrType;

                if (uniqueAdverts.find(stringAdvert) != null) {
                    continue;
                }

                uniqueAdverts.push(stringAdvert);

                local resultAdvert = {
                    "address" : address,
                    "rssi"    : regexCapture[ESP32_BLE_PARAM_ORDER.RSSI].tointeger(),
                    "advData" : advData.len() >= 2 ? utilities.hexStringToBlob(advData) : blob(),
                    "addrType": addrType
                };

                result.push(resultAdvert);
            }

            return result;
        } catch (err) {
            throw "BLE advertisements parsing error: " + err;
        }
    }
}

//line 2 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/AccelerometerDriver.device.nut"

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

    // accelerometer I2C address
    _addr = null;

    // I2C is connected to
    _i2c  = null;

    // accelerometer object
    _accel = null;

    // shock threshold value
    _shockThr = null

    // duration of exceeding the movement acceleration threshold
    _movementDur = null;

    // current movement acceleration threshold
    _movementCurThr = null;

    // maximum value of acceleration threshold for bounce filtering
    _movementMax = null;

    // minimum value of acceleration threshold for bounce filtering
    _movementMin = null;

    // maximum time to determine motion detection after the initial movement
    _motionTimeout = null;

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
     * @param {integer} addr - I2C address of accelerometer. Optional.
     *                         Default: ACCEL_DEFAULT_I2C_ADDR
     * An exception will be thrown in case of accelerometer configuration error.
     */
    constructor(i2c, intPin, addr = ACCEL_DEFAULT_I2C_ADDR) {
        _enMtnDetect = false;
        _enShockDetect = false;
        _thrVelExceeded = false;
        _shockThr = ACCEL_DEFAULT_SHOCK_THR;
        _movementCurThr = ACCEL_DEFAULT_MOV_MIN;
        _movementMin = ACCEL_DEFAULT_MOV_MIN;
        _movementMax = ACCEL_DEFAULT_MOV_MAX;
        _movementDur = ACCEL_DEFAULT_MOV_DUR;
        _motionCurTime = time();
        _motionVelocity = ACCEL_DEFAULT_MOTION_VEL;
        _motionTimeout = ACCEL_DEFAULT_MOTION_TIME;
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

        _i2c = i2c;
        _addr = addr;
        _intPin = intPin;

        try {
            _i2c.configure(CLOCK_SPEED_400_KHZ);
            _accel = LIS3DH(_i2c, _addr);
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
            _accel.configureInterruptLatching(false);
            _intPin.configure(DIGITAL_IN_WAKEUP, _checkInt.bindenv(this));
            _accel._getReg(LIS2DH12_REFERENCE);
            ::debug("Accelerometer configured", "AccelerometerDriver");
        } catch (e) {
            throw "Accelerometer configuration error: " + e;
        }
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
     *          "shockThreshold": {float} - Shock acceleration threshold, in g.
     *                                      Default: ACCEL_DEFAULT_SHOCK_THR
     */
    function enableShockDetection(shockCb, shockCnd = {}) {
        local shockSettIsCorr = true;
        _shockThr = ACCEL_DEFAULT_SHOCK_THR;
        foreach (key, value in shockCnd) {
            if (typeof key == "string") {
                if (key == "shockThreshold") {
                    if (typeof value == "float" && value > 0.0 && value <= 16.0) {
                        _shockThr = value;
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
            // TODO: deal with the shock after initialization
            // accelerometer range determined by the value of shock threashold
            local range = _accel.setRange(_shockThr.tointeger());
            ::info(format("Accelerometer range +-%d g", range), "AccelerometerDriver");
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
     * after that the detection is automatically disabled and
     * (if needed) should be explicitly re-enabled again.
     * @param {function} motionCb - Callback to be called once when the motion condition is detected.
     *        The callback has no parameters. If null or not a function, the motion detection is disabled.
     *        Otherwise, the motion detection is (re-)enabled for the provided motion condition.
     * @param {table} motionCnd - Table with the motion condition settings.
     *        Optional, all settings have defaults.
     *        The settings:
     *          "movementMax": {float}    - Movement acceleration maximum threshold, in g.
     *                                        Default: ACCEL_DEFAULT_MOV_MAX
     *          "movementMin": {float}    - Movement acceleration minimum threshold, in g.
     *                                        Default: ACCEL_DEFAULT_MOV_MIN
     *          "movementDur": {float}    - Duration of exceeding movement acceleration threshold, in seconds.
     *                                        Default: ACCEL_DEFAULT_MOV_DUR
     *          "motionTimeout": {float}  - Maximum time to determine motion detection after the initial movement, in seconds.
     *                                        Default: ACCEL_DEFAULT_MOTION_TIME
     *          "motionVelocity": {float} - Minimum instantaneous velocity  to determine motion detection condition, in meters per second.
     *                                        Default: ACCEL_DEFAULT_MOTION_VEL
     *          "motionDistance": {float} - Minimal movement distance to determine motion detection condition, in meters.
     *                                      If 0, distance is not calculated (not used for motion detection).
     *                                        Default: ACCEL_DEFAULT_MOTION_DIST
     */
    function detectMotion(motionCb, motionCnd = {}) {
        local motionSettIsCorr = true;
        _movementCurThr = ACCEL_DEFAULT_MOV_MIN;
        _movementMin = ACCEL_DEFAULT_MOV_MIN;
        _movementMax = ACCEL_DEFAULT_MOV_MAX;
        _movementDur = ACCEL_DEFAULT_MOV_DUR;
        _motionVelocity = ACCEL_DEFAULT_MOTION_VEL;
        _motionTimeout = ACCEL_DEFAULT_MOTION_TIME;
        _motionDistance = ACCEL_DEFAULT_MOTION_DIST;
        foreach (key, value in motionCnd) {
            if (typeof key == "string") {
                if (key == "movementMax") {
                    if (typeof value == "float" && value > 0) {
                        _movementMax = value;
                    } else {
                        ::error("movementMax incorrect value", "AccelerometerDriver");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "movementMin") {
                    if (typeof value == "float"  && value > 0) {
                        _movementMin = value;
                        _movementCurThr = value;
                    } else {
                        ::error("movementMin incorrect value", "AccelerometerDriver");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "movementDur") {
                    if (typeof value == "float"  && value > 0) {
                        _movementDur = value;
                    } else {
                        ::error("movementDur incorrect value", "AccelerometerDriver");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "motionTimeout") {
                    if (typeof value == "float"  && value > 0) {
                        _motionTimeout = value;
                    } else {
                        ::error("motionTimeout incorrect value", "AccelerometerDriver");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "motionVelocity") {
                    if (typeof value == "float"  && value >= 0) {
                        _motionVelocity = value;
                    } else {
                        ::error("motionVelocity incorrect value", "AccelerometerDriver");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "motionDistance") {
                    if (typeof value == "float"  && value >= 0) {
                        _motionDistance = value;
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
                                              (_movementDur*ACCEL_DEFAULT_DATA_RATE).tointeger());
            ::info("Motion detection enabled", "AccelerometerDriver");
        } else {
            _mtnCb = null;
            _enMtnDetect = false;
            _motionState = ACCEL_MOTION_STATE.DISABLED;
            _positionCur.clear();
            _positionPrev.clear();
            _movementCurThr = _movementMin;
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
     * Handler to check interrupt from accelerometer
     */
    function _checkInt() {
        if (_intPin.read() == 0)
            return;

        local intTable = _accel.getInterruptTable();

        if (intTable.singleClick) {
            ::debug("Shock interrupt", "AccelerometerDriver");
            if (_shockCb && _enShockDetect) {
                _shockCb();
            }
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
     *
     */
    function _confirmMotion() {
        local vel = _velCur.length();
        local moving = _positionCur.length();

        local diffTm = time() - _motionCurTime;
        if (diffTm < _motionTimeout) {
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
            if (_movementCurThr < _movementMax) {
                _movementCurThr += ACCEL_DEFAULT_MOV_STEP;
                if (_movementCurThr > _movementMax)
                    _movementCurThr = _movementMax;
            }
            ::debug(format("Motion is NOT confirmed. New movementCurThr %f g", _movementCurThr), "AccelerometerDriver")
            _positionCur.clear();
            _positionPrev.clear();
            _accel.configureFifoInterrupts(false);
            _accel.configureInertialInterrupt(true, _movementCurThr, (_movementDur*ACCEL_DEFAULT_DATA_RATE).tointeger());
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
            _movementCurThr = _movementMin;
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

//line 2 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/MotionMonitor.device.nut"

// Mean earth radius in meters (https://en.wikipedia.org/wiki/Great-circle_distance)
const MM_EARTH_RAD = 6371009;

// min longitude
const MM_MIN_LNG = -180.0;
// max latitude
const MM_MAX_LNG = 180.0;
// min latitude
const MM_MIN_LAT = -90.0;
// max latitude
const MM_MAX_LAT = 90.0;

// Motion Monitor class.
// Starts and stops motion monitoring.
class MotionMonitor {

    // Accelerometer driver object
    _ad = null;

    // Location driver object
    _ld = null;

    // New location callback function
    _newLocCb = null;

    // Motion event callback function
    _motionEventCb = null;

    // Geofencing event callback function
    _geofencingEventCb = null;

    // Location reading timer period
    _locReadingPeriod = null;

    // Location reading timer
    _locReadingTimer = null;

    // Promise of the location reading process or null
    _locReadingPromise = null;

    // Motion stop assumption
    _motionStopAssumption = null;

    // Moton state
    _inMotion = null;

    // Current location
    _curLoc = null;

    // Sign of the current location relevance
    _curLocFresh = null;

    // Previous location
    _prevLoc = null;

    // Sign of the previous location relevance
    _prevLocFresh = null;

    // Movement acceleration threshold range: maximum level
    _movementMax = null;

    // Movement acceleration threshold range: minimum (starting) level
    _movementMin = null;

    // Duration of exceeding movement acceleration threshold
    _movementDur = null;

    // Maximum time to determine motion detection after the initial movement
    _motionTimeout = null;

    // Minimal instantaneous velocity to determine motion detection condition
    _motionVelocity = null;

    // Minimal movement distance to determine motion detection condition
    _motionDistance = null;

    // geofence zone center location
    _geofenceCenter = null;

    // geofence zone radius
    _geofenceRadius = null;

    // enable/disable flag
    _geofenceIsEnable = null;

    // in zone or not
    _inGeofenceZone = null;

    /**
     *  Constructor for Motion Monitor class.
     *  @param {object} accelDriver - Accelerometer driver object.
     *  @param {object} locDriver - Location driver object.
     */
    constructor(accelDriver, locDriver) {
        _ad = accelDriver;
        _ld = locDriver;

        _geofenceIsEnable = false;
        _geofenceRadius = 0.0;
        _motionStopAssumption = false;
        _inMotion = false;
        _curLocFresh = false;
        _prevLocFresh = false;
        _curLoc = {"timestamp": 0,
                   "type": "gnss",
                   "accuracy": MM_EARTH_RAD,
                   "longitude": INIT_LONGITUDE,
                   "latitude": INIT_LATITUDE};
        _prevLoc = {"timestamp": 0,
                    "type": "gnss",
                    "accuracy": MM_EARTH_RAD,
                    "longitude": INIT_LONGITUDE,
                    "latitude": INIT_LATITUDE};
        _geofenceCenter = {"longitude": INIT_LONGITUDE,
                            "latitude": INIT_LATITUDE};
        _locReadingPeriod = DEFAULT_LOCATION_READING_PERIOD;
        _movementMax = DEFAULT_MOVEMENT_ACCELERATION_MAX;
        _movementMin = DEFAULT_MOVEMENT_ACCELERATION_MIN;
        _movementDur = DEFAULT_MOVEMENT_ACCELERATION_DURATION;
        _motionTimeout = DEFAULT_MOTION_TIME;
        _motionVelocity = DEFAULT_MOTION_VELOCITY;
        _motionDistance = DEFAULT_MOTION_DISTANCE;
    }

    /**
     *   Start motion monitoring.
     *   @param {table} motionMonSettings - Table with the settings.
     *        Optional, all settings have defaults.
     *        If a setting is missed, it is reset to default.
     *        The settings:
     *          "locReadingPeriod": {float} - Location reading period, in seconds.
     *                                          Default: DEFAULT_LOCATION_READING_PERIOD
     *          "movementMax": {float}    - Movement acceleration maximum threshold, in g.
     *                                        Default: DEFAULT_MOVEMENT_ACCELERATION_MAX
     *          "movementMin": {float}    - Movement acceleration minimum threshold, in g.
     *                                        Default: DEFAULT_MOVEMENT_ACCELERATION_MIN
     *          "movementDur": {float}    - Duration of exceeding movement acceleration threshold, in seconds.
     *                                        Default: DEFAULT_MOVEMENT_ACCELERATION_DURATION
     *          "motionTimeout": {float}  - Maximum time to determine motion detection after the initial movement, in seconds.
     *                                        Default: DEFAULT_MOTION_TIME
     *          "motionVelocity": {float} - Minimum instantaneous velocity  to determine motion detection condition, in meters per second.
     *                                        Default: DEFAULT_MOTION_VELOCITY
     *          "motionDistance": {float} - Minimal movement distance to determine motion detection condition, in meters.
     *                                      If 0, distance is not calculated (not used for motion detection).
     *                                        Default: DEFAULT_MOTION_DISTANCE
     */
    function start(motionMonSettings = {}) {
        _locReadingPeriod = DEFAULT_LOCATION_READING_PERIOD;
        _movementMax = DEFAULT_MOVEMENT_ACCELERATION_MAX;
        _movementMin = DEFAULT_MOVEMENT_ACCELERATION_MIN;
        _movementDur = DEFAULT_MOVEMENT_ACCELERATION_DURATION;
        _motionTimeout = DEFAULT_MOTION_TIME;
        _motionVelocity = DEFAULT_MOTION_VELOCITY;
        _motionDistance = DEFAULT_MOTION_DISTANCE;

        // check and set the settings
        _checkMotionMonSettings(motionMonSettings);

        // get current location
        _locReading();

        // initial state after start: not in motion
        _motionStopAssumption = false;
        _inMotion = false;

        // detect motion start
        _ad.detectMotion(_onAccelMotionDetected.bindenv(this), {"movementMax"      : _movementMax,
                                                                "movementMin"      : _movementMin,
                                                                "movementDur"      : _movementDur,
                                                                "motionTimeout"    : _motionTimeout,
                                                                "motionVelocity"   : _motionVelocity,
                                                                "motionDistance"   : _motionDistance});
    }

    /**
     *   Stop motion monitoring.
     */
    function stop() {
        _locReadingTimer && imp.cancelwakeup(_locReadingTimer);
    }

    /**
     *  Set new location callback function.
     *  @param {function | null} locCb - The callback will be called every time the new location is received (null - disables the callback)
     *                 locCb(loc), where
     *                 @param {table} loc - Location information
     *                      The fields:
     *                          "timestamp": {integer}  - The number of seconds that have elapsed since midnight on 1 January 1970.
     *                               "type": {string}   - "gnss", "cell", "wifi", "ble"
     *                           "accuracy": {integer}  - Accuracy in meters
     *                          "longitude": {float}    - Longitude in degrees
     *                           "latitude": {float}    - Latitude in degrees
     */
    function setNewLocationCb(locCb) {
        if (typeof locCb == "function" || locCb == null) {
            _newLocCb = locCb;
        } else {
            ::error("Argument not a function or null", "MotionMonitor");
        }
    }

    /**
     *  Set motion event callback function.
     *  @param {function | null} motionEventCb - The callback will be called every time the new motion event is detected (null - disables the callback)
     *                 motionEventCb(ev), where
     *                 @param {bool} ev - true: motion started, false: motion stopped
     */
    function setMotionEventCb(motionEventCb) {
        if (typeof motionEventCb == "function" || motionEventCb == null) {
            _motionEventCb = motionEventCb;
        } else {
            ::error("Argument not a function or null", "MotionMonitor");
        }
    }

    /**
     *  Set geofencing event callback function.
     *  @param {function | null} geofencingEventCb - The callback will be called every time the new geofencing event is detected (null - disables the callback)
     *                 geofencingEventCb(ev), where
     *                 @param {bool} ev - true: geofence entered, false: geofence exited
     */
    function setGeofencingEventCb(geofencingEventCb) {
        if (typeof geofencingEventCb == "function" || geofencingEventCb == null) {
            _geofencingEventCb = geofencingEventCb;
        } else {
            ::error("Argument not a function or null", "MotionMonitor");
        }
    }

    /**
     *  Enable/disable and set settings for geofencing.
     *  @param {table} settings - Table with the center coordinates of geofence zone, radius.
     *      The settings include:
     *          "enabled"   : {bool}  - Enable/disable, true - geofence is enabled.
     *          "lng"       : {float} - Center longitude, in degrees.
     *          "lat"       : {float} - Center latitude, in degrees.
     *          "radius"    : {float} - Radius, in meters. (value must exceed the accuracy of the coordinate)
     */
    function configureGeofence(settings) {
        // reset in zone flag
        _inGeofenceZone = null;
        if (settings != null && typeof settings == "table") {
            _geofenceIsEnable = false;
            if ("enabled" in settings) {
                if (typeof settings.enabled == "bool") {
                    ::info("Geofence is " + (settings.enabled ? "enabled" : "disabled"), "MotionMonitor");
                    _geofenceIsEnable = settings.enabled;
                }
            }
            _geofenceRadius = 0.0;
            if ("radius" in settings) {
                if (typeof settings.radius == "float" && 
                    settings.radius >= 0) {
                    ::info("Geofence radius: " + settings.radius, "MotionMonitor");
                    _geofenceRadius = settings.radius > MM_EARTH_RAD ? MM_EARTH_RAD : settings.radius;
                }
            }
            _geofenceCenter = {"longitude": INIT_LONGITUDE,
                               "latitude" : INIT_LATITUDE};
            if ("lng" in settings && "lat" in settings) {
                if (typeof settings.lat == "float") {
                    ::info("Geofence latitude: " + settings.lat, "MotionMonitor");
                    _geofenceCenter.latitude = settings.lat;
                    if (_geofenceCenter.latitude < MM_MIN_LAT) {
                        ::error("Geofence latitude not in range [-90;90]: " + settings.lat, "MotionMonitor");
                        _geofenceCenter.latitude = MM_MIN_LAT;
                    }
                    if (_geofenceCenter.latitude > MM_MAX_LAT) {
                        ::error("Geofence latitude not in range [-90;90]: " + settings.lat, "MotionMonitor");
                        _geofenceCenter.latitude = MM_MAX_LAT;
                    }
                    ::info("Geofence longitude: " + settings.lng, "MotionMonitor");
                    _geofenceCenter.longitude = settings.lng;
                    if (_geofenceCenter.longitude < MM_MIN_LNG) {
                        ::error("Geofence longitude not in range [-180;180]: " + settings.lng, "MotionMonitor");
                        _geofenceCenter.longitude = MM_MIN_LAT;
                    }
                    if (_geofenceCenter.longitude > MM_MAX_LAT) {
                        ::error("Geofence longitude not in range [-180;180]: " + settings.lng, "MotionMonitor");
                        _geofenceCenter.longitude = MM_MAX_LAT;
                    }
                }
            }
        }
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Check settings element.
     * Returns the specified value if the check fails.
     *
     * @param {float} val - Value of settings element.
     * @param {float} defVal - Default value of settings element.
     * @param {bool} flCheckSignEq - Flag for sign check.
     *
     * @return {float} If success - value, else - default value.
     */
    function _checkVal(val, defVal, flCheckSignEq = true) {
        if (typeof val == "float") {
            if (flCheckSignEq) {
                if (val >= 0.0) {
                    return val;
                }
            } else {
                if (val > 0.0) {
                    return val;
                }
            }
        } else {
            ::error("Incorrect type of settings parameter", "MotionMonitor");
        }

        return defVal;
    }

    /**
     *  Check and set settings.
     *  Sets default values for incorrect settings.
     *
     *   @param {table} motionMonSettings - Table with the settings.
     *        Optional, all settings have defaults.
     *        The settings:
     *          "locReadingPeriod": {float} - Location reading period, in seconds.
     *                                          Default: DEFAULT_LOCATION_READING_PERIOD
     *          "movementMax": {float}    - Movement acceleration maximum threshold, in g.
     *                                        Default: DEFAULT_MOVEMENT_ACCELERATION_MAX
     *          "movementMin": {float}    - Movement acceleration minimum threshold, in g.
     *                                        Default: DEFAULT_MOVEMENT_ACCELERATION_MIN
     *          "movementDur": {float}    - Duration of exceeding movement acceleration threshold, in seconds.
     *                                        Default: DEFAULT_MOVEMENT_ACCELERATION_DURATION
     *          "motionTimeout": {float}  - Maximum time to determine motion detection after the initial movement, in seconds.
     *                                        Default: DEFAULT_MOTION_TIME
     *          "motionVelocity": {float} - Minimum instantaneous velocity  to determine motion detection condition, in meters per second.
     *                                        Default: DEFAULT_MOTION_VELOCITY
     *          "motionDistance": {float} - Minimal movement distance to determine motion detection condition, in meters.
     *                                      If 0, distance is not calculated (not used for motion detection).
     *                                        Default: DEFAULT_MOTION_DISTANCE
     */
    function _checkMotionMonSettings(motionMonSettings) {
        foreach (key, value in motionMonSettings) {
            if (typeof key == "string") {
                switch(key){
                    case "locReadingPeriod":
                        _locReadingPeriod = _checkVal(value, DEFAULT_LOCATION_READING_PERIOD);
                        break;
                    case "movementMax":
                        _movementMax = _checkVal(value, DEFAULT_MOVEMENT_ACCELERATION_MAX, false);
                        break;
                    case "movementMin":
                        _movementMin = _checkVal(value, DEFAULT_MOVEMENT_ACCELERATION_MIN, false);
                        break;
                    case "movementDur":
                        _movementDur = _checkVal(value, DEFAULT_MOVEMENT_ACCELERATION_DURATION, false);
                        break;
                    case "motionTimeout":
                        _motionTimeout = _checkVal(value, DEFAULT_MOTION_TIME, false);
                        break;
                    case "motionVelocity":
                        _motionVelocity = _checkVal(value, DEFAULT_MOTION_VELOCITY);
                        break;
                    case "motionDistance":
                        _motionDistance = _checkVal(value, DEFAULT_MOTION_DISTANCE);
                        break;
                    default:
                        ::error("Incorrect key name", "MotionMonitor");
                        break;
                }
            } else {
                ::error("Incorrect motion condition settings", "MotionMonitor");
            }
        }
    }

    /**
     *  Location reading timer callback function.
     */
    function _locReadingTimerCb() {
        local start = hardware.millis();

        if (_motionStopAssumption) {
            // no movement during location reading period =>
            // motion stop is confirmed
            _inMotion = false;
            _motionStopAssumption = false;
            if (_motionEventCb) {
                _motionEventCb(_inMotion);
            }
        } else {
            // read location and, after that, check if it is the same as the previous one
            _locReading()
            .finally(function(_) {
                _checkMotionStop();

                // Calculate the delay for the timer according to the time spent on location reading and etc.
                local delay = _locReadingPeriod - (hardware.millis() - start) / 1000.0;
                _locReadingTimer && imp.cancelwakeup(_locReadingTimer);
                _locReadingTimer = imp.wakeup(delay, _locReadingTimerCb.bindenv(this));
            }.bindenv(this));
        }
    }

    /**
     *  Try to determine the current location
     */
    function _locReading() {
        if (_locReadingPromise) {
            return _locReadingPromise;
        }

        _prevLoc = _curLoc;
        _prevLocFresh = _curLocFresh;

        ::debug("Getting location..", "MotionMonitor");

        return _locReadingPromise = _ld.getLocation()
        .then(function(loc) {
            _locReadingPromise = null;
            _curLoc = loc;
            _curLocFresh = true;
            _newLocCb && _newLocCb(_curLoc);
            _procGeofence(loc);
        }.bindenv(this), function(_) {
            _locReadingPromise = null;

            // the current location becomes non-fresh
            _curLoc = _prevLoc;
            _curLocFresh = false;
        }.bindenv(this));
    }

    /**
     *  Check if the motion is stopped
     */
    function _checkMotionStop() {
        if (_curLocFresh) {

            local dist = 0;
            if (_curLoc && _prevLoc) {
                // calculate distance between two locations
                dist = _greatCircleDistance(_curLoc, _prevLoc);
            } else {
                ::error("Location is null", "MotionMonitor");
            }
            ::debug("Distance: " + dist, "MotionMonitor");

            // check if the distance is less than 2 radius of accuracy
            if (dist < 2*_curLoc.accuracy) {
                // maybe motion is stopped, need to double check
                _motionStopAssumption = true;
            } else {
                // still in motion
                if (!_inMotion) {
                    _inMotion = true;
                    _motionEventCb && _motionEventCb(_inMotion);
                }
            }
        }

        if (!_curLocFresh && !_prevLocFresh) {
            // the location has not been determined two times in a raw,
            // need to double check the motion
            _motionStopAssumption = true;
        }

        if(_motionStopAssumption) {
            // enable motion detection by accelerometer to double check the motion
            _ad.detectMotion(_onAccelMotionDetected.bindenv(this), {"movementMax"      : _movementMax,
                                                                    "movementMin"      : _movementMin,
                                                                    "movementDur"      : _movementDur,
                                                                    "motionTimeout"    : _motionTimeout,
                                                                    "motionVelocity"   : _motionVelocity,
                                                                    "motionDistance"   : _motionDistance});
        }
    }

    /**
     *  The handler is called when the motion is detected by accelerometer
     */
    function _onAccelMotionDetected() {
        _motionStopAssumption = false;
        if (!_inMotion) {
            _inMotion = true;

            // start reading location
            _locReading();
            _motionEventCb && _motionEventCb(_inMotion);

            _locReadingTimer && imp.cancelwakeup(_locReadingTimer);
            _locReadingTimer = imp.wakeup(_locReadingPeriod, _locReadingTimerCb.bindenv(this));
        }
    }

    /**
     *  Zone border crossing check.
     *  
     *   @param {table} curLocation - Table with the current location.
     *        The table must include parts:
     *          "accuracy" : {integer}  - Accuracy, in meters.
     *          "longitude": {float}    - Longitude, in degrees.
     *          "latitude" : {float}    - Latitude, in degrees.  
     */
    function _procGeofence(curLocation) {
        if (_geofenceIsEnable) {
            local dist = _greatCircleDistance(_geofenceCenter, curLocation);               //       _____GeofenceZone
            ::debug("Geofence distance: " + dist, "MotionMonitor");                        //      /      \
            if (dist > _geofenceRadius) {                                                  //     / __    R\    dist    __Location
                local distWithoutAccurace = dist - curLocation.accuracy;                   //    | /\ \ .---|----------/- \
                if (distWithoutAccurace > 0 && distWithoutAccurace > _geofenceRadius) {    //    | \__/     |          \_\/acc.
                    if (_inGeofenceZone == null || _inGeofenceZone == true) {              //     \ Location/
                        _geofencingEventCb && _geofencingEventCb(false);                   //      \______ /
                        _inGeofenceZone = false;                                           //       
                    }                                                                      //
                }
            } else {
                local distWithAccurace = dist + curLocation.accuracy;
                if (distWithAccurace <= _geofenceRadius) {
                    if (_inGeofenceZone == null || _inGeofenceZone == false) {
                        _geofencingEventCb && _geofencingEventCb(true);
                        _inGeofenceZone = true;
                    }
                }
            }
        }
    }

    /**
     *  Calculate distance between two locations.
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
    function _greatCircleDistance(locationFirstPoint, locationSecondPoint) {
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

        return dist
    }
}

//line 2 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/DataProcessor.device.nut"

// Temperature state enum
enum DP_TEMPERATURE_LEVEL {
    T_BELOW_RANGE,
    T_IN_RANGE,
    T_HIGHER_RANGE
};

// Battery voltage state enum
enum DP_BATTERY_VOLT_LEVEL {
    V_IN_RANGE,
    V_NOT_IN_RANGE
};

// Temperature hysteresis
const DP_TEMPER_HYST = 1.0;

// Init impossible temperature value
const DP_INIT_TEMPER_VALUE = -300.0;

// Init battery level
const DP_INIT_BATTERY_LEVEL = 0;

// Battery level hysteresis
const DP_BATTERY_LEV_HYST = 2.0;

// Data Processor class.
// Processes data, saves and sends messages
class DataProcessor {

    // Data reading timer period
    _dataReadingPeriod = null;

    // Data reading timer handler
    _dataReadingTimer = null;

    // Data sending timer period
    _dataSendingPeriod = null;

    // Data sending timer handler
    _dataSendingTimer = null;

    // Result message
    _dataMesg = null;

    // Thermosensor driver object
    _ts = null;

    // Accelerometer driver object
    _ad = null;

    // Motion Monitor driver object
    _mm = null;

    // Last temperature value
    _curTemper = null;

// TODO: Save location between restarts
// TODO: Reset alerts between restarts and re-configurations (if the cfg impacts this alert)
// TODO: Add inGeofence
    // Last location
    _currentLocation = null;

    // Moton state
    _inMotion = null;

    // Last battery level
    _curBatteryLev = null;

    // Battery low threshold
    _batteryLowThr = null;

    // Temperature high alert threshold variable
    _temperatureHighAlertThr = null;

    // Temperature low alert threshold variable
    _temperatureLowAlertThr = null;

    // Array of alerts
    _allAlerts = null;

    // Shock threshold value
    _shockThreshold = null;

    // state battery (voltage in permissible range or not)
    _batteryState = null;

    // temperature state (temperature in permissible range or not)
    _temperatureState = null;

    /**
     *  Constructor for Data Processor class.
     *  @param {object} motionMon - Motion monitor object.
     *  @param {object} accelDriver - Accelerometer driver object.
     *  @param {object} temperDriver - Temperature sensor driver object.
     *  @param {object} batDriver - Battery driver object.
     */
    constructor(motionMon, accelDriver, temperDriver, batDriver) {
        _ad = accelDriver;
        _mm = motionMon;
        _ts = temperDriver;
        _currentLocation = {"timestamp": 0,
                            "type": "gnss",
                            "accuracy": MM_EARTH_RAD,
                            "longitude": INIT_LONGITUDE,
                            "latitude": INIT_LATITUDE};
        _curBatteryLev = DP_INIT_BATTERY_LEVEL;
        _curTemper = DP_INIT_TEMPER_VALUE;
        _batteryState = DP_BATTERY_VOLT_LEVEL.V_IN_RANGE;
        _temperatureState = DP_TEMPERATURE_LEVEL.T_IN_RANGE;
        _inMotion = false;
        _allAlerts = { "shockDetected"      : false,
                       "motionStarted"      : false,
                       "motionStopped"      : false,
                       "geofenceEntered"    : false,
                       "geofenceExited"     : false,
                       "temperatureHigh"    : false,
                       "temperatureLow"     : false,
                       "batteryLow"         : false};
        _temperatureHighAlertThr = DEFAULT_TEMPERATURE_HIGH;
        _temperatureLowAlertThr = DEFAULT_TEMPERATURE_LOW;
        _dataReadingPeriod = DEFAULT_DATA_READING_PERIOD;
        _dataSendingPeriod = DEFAULT_DATA_SENDING_PERIOD;
        _batteryLowThr = DEFAULT_BATTERY_LOW;
        _shockThreshold = DEFAULT_SHOCK_THRESHOLD;
    }

    /**
     *  Start data processing.
     *   @param {table} dataProcSettings - Table with the settings.
     *        Optional, all settings have defaults.
     *        If a setting is missed, it is reset to default.
     *        The settings:
     *          "temperatureHighAlertThr": {float} - Temperature high alert threshold, in Celsius.
     *                                          Default: DEFAULT_TEMPERATURE_HIGH
     *           "temperatureLowAlertThr": {float} - Temperature low alert threshold, in Celsius.
     *                                          Default: DEFAULT_TEMPERATURE_LOW
     *                "dataReadingPeriod": {float} - Data reading period, in seconds.
     *                                          Default: DEFAULT_DATA_READING_PERIOD
     *                "dataSendingPeriod": {float} - Data sending period, in seconds.
     *                                          Default: DEFAULT_DATA_SENDING_PERIOD
     *                    "batteryLowThr": {float} - Battery low alert threshold
     *                                          Default: DEFAULT_BATTERY_LOW
     *                   "shockThreshold": {float} - Shock acceleration threshold, in g.
     *                                          Default: DEFAULT_SHOCK_THRESHOLD
     */
    function start(dataProcSettings = {}) {
        _temperatureHighAlertThr = DEFAULT_TEMPERATURE_HIGH;
        _temperatureLowAlertThr = DEFAULT_TEMPERATURE_LOW;
        _dataReadingPeriod = DEFAULT_DATA_READING_PERIOD;
        _dataSendingPeriod = DEFAULT_DATA_SENDING_PERIOD;
        _batteryLowThr = DEFAULT_BATTERY_LOW;
        _shockThreshold = DEFAULT_SHOCK_THRESHOLD;

        _checkDataProcSettings(dataProcSettings);

        if (_ad) {
            _ad.enableShockDetection(_onShockDetectedEvent.bindenv(this),
                                     {"shockThreshold" : _shockThreshold});
        } else {
            ::info("Accelerometer driver object is null", "DataProcessor");
        }

        if (_mm) {
            _mm.setNewLocationCb(_onNewLocation.bindenv(this));
            _mm.setMotionEventCb(_onMotionEvent.bindenv(this));
            _mm.setGeofencingEventCb(_onGeofencingEvent.bindenv(this));
        } else {
            ::info("Motion monitor object is null", "DataProcessor");
        }

        // starts periodic data reading and sending
        _dataReadingTimer = imp.wakeup(_dataReadingPeriod,
                                       _dataProcTimerCb.bindenv(this));
        _dataSendingTimer = imp.wakeup(_dataSendingPeriod,
                                       _dataSendTimerCb.bindenv(this));
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Check settings element.
     * Returns the specified value if the check fails.
     *
     * @param {float} val - Value of settings element.
     * @param {float} defVal - Default value of settings element.
     * @param {bool} flCheckSign - Flag for sign check.
     *
     * @return {float} If success - value, else - default value.
     */
    function _checkVal(val, defVal, flCheckSign = false) {
        if (typeof val == "float") {
            if (flCheckSign) {
                if (val > 0.0) {
                    return val;
                }
            } else {
                return val;
            }
        } else {
            ::error("Incorrect type of settings parameter", "DataProcessor");
        }

        return defVal;
    }

    /**
     *  Check and set settings.
     *  Sets default values for incorrect settings.
     *
     *   @param {table} dataProcSettings - Table with the settings.
     *        Optional, all settings have defaults.
     *        The settings:
     *          "temperatureHighAlertThr": {float} - Temperature high alert threshold, in Celsius.
     *                                          Default: DEFAULT_TEMPERATURE_HIGH
     *           "temperatureLowAlertThr": {float} - Temperature low alert threshold, in Celsius.
     *                                          Default: DEFAULT_TEMPERATURE_LOW
     *                "dataReadingPeriod": {float} - Data reading period, in seconds.
     *                                          Default: DEFAULT_DATA_READING_PERIOD
     *                "dataSendingPeriod": {float} - Data sending period, in seconds.
     *                                          Default: DEFAULT_DATA_SENDING_PERIOD
     *                    "batteryLowThr": {float} - Battery low alert threshold
     *                                          Default: DEFAULT_BATTERY_LOW
     *                   "shockThreshold": {float} - Shock acceleration threshold, in g.
     *                                      Default: DEFAULT_SHOCK_THRESHOLD
     */
    function _checkDataProcSettings(dataProcSettings) {
        foreach (key, value in dataProcSettings) {
            if (typeof key == "string") {
                switch(key) {
                    case "temperatureHighAlertThr":
                        _temperatureHighAlertThr = _checkVal(key, value, DEFAULT_TEMPERATURE_HIGH);
                        break;
                    case "temperatureLowAlertThr":
                        _temperatureLowAlertThr = _checkVal(key, value, DEFAULT_TEMPERATURE_LOW);
                        break;
                    case "dataReadingPeriod":
                        _dataReadingPeriod = _checkVal(key, value, DEFAULT_DATA_READING_PERIOD);
                        break;
                    case "dataSendingPeriod":
                        _dataSendingPeriod = _checkVal(key, value, DEFAULT_DATA_SENDING_PERIOD);
                        break;
                    case "batteryLowThr":
                        _batteryLowThr = _checkVal(key, value, DEFAULT_BATTERY_LOW);
                        break;
                    case "shockThreshold":
                        _shockThreshold = _checkVal(key, value, DEFAULT_SHOCK_THRESHOLD, true);
                        break;
                    default:
                        ::error("Incorrect key name", "DataProcessor");
                        break;
                }
            } else {
                ::error("Incorrect key type", "DataProcessor");
            }
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

        _dataReadingTimer && imp.cancelwakeup(_dataReadingTimer);

        // read temperature, check alert conditions
        _checkTemperature();

        // read battery level, check alert conditions
        _checkBatteryVoltLevel();

        // check if alerts have been triggered
        local alerts = [];
        foreach (key, val in _allAlerts) {
            if (val) {
                alerts.append(key.tostring());
            }
            _allAlerts[key] = false;
        }
        local alertsCount = alerts.len();

        _dataMesg = {"trackerId":hardware.getdeviceid(),
                      "timestamp": time(),
                      "status":{"inMotion":_inMotion},
                                "location":{"timestamp": _currentLocation.timestamp,
                                    "type": _currentLocation.type,
                                    "accuracy": _currentLocation.accuracy,
                                    "lng": _currentLocation.longitude,
                                    "lat": _currentLocation.latitude},
                       "sensors":{"temperature": _curTemper == DP_INIT_TEMPER_VALUE ? 0 : _curTemper}, // send 0 degrees of Celsius if termosensor error
                       "alerts":alerts};

        ::debug("Message: trackerId: " + _dataMesg.trackerId + ", timestamp: " + _dataMesg.timestamp +
               ", inMotion: " + _inMotion +
               ", location timestamp: " + _currentLocation.timestamp + ", type: " +
               _currentLocation.type + ", accuracy: " + _currentLocation.accuracy +
               ", lng: " + _currentLocation.longitude + ", lat: " + _currentLocation.latitude +
               ", temperature: " + _curTemper, "DataProcessor");
        if (alertsCount > 0) {
            ::info("Alerts:", "DataProcessor");
            foreach (item in alerts) {
                ::info(item, "DataProcessor");
            }
        }

        // ReplayMessenger saves the message till imp-device is connected
        rm.send(APP_RM_MSG_NAME.DATA, clone _dataMesg, RM_IMPORTANCE_HIGH);
        ledIndication && ledIndication.indicate(LI_EVENT_TYPE.NEW_MSG);

        // If at least one alert, try to send data immediately
        if (alertsCount > 0) {
            _dataSend();
        }

        _dataReadingTimer = imp.wakeup(_dataReadingPeriod,
                                       _dataProcTimerCb.bindenv(this));
    }

    /**
     *  Read temperature, check alert conditions
     */
    function _checkTemperature() {
        local res = _ts.read();
        if ("error" in res) {
            ::error("Failed to read temperature: " + res.error, "DataProcessor");
            _curTemper = DP_INIT_TEMPER_VALUE;
        } else {
            _curTemper = res.temperature;
            ::debug("Temperature: " + _curTemper);
        }

        if (_curTemper > _temperatureHighAlertThr) {
            if (_temperatureState != DP_TEMPERATURE_LEVEL.T_HIGHER_RANGE) {
                _allAlerts.temperatureHigh = true;
                _temperatureState = DP_TEMPERATURE_LEVEL.T_HIGHER_RANGE;

                ledIndication && ledIndication.indicate(LI_EVENT_TYPE.ALERT_TEMP_HIGH);
            }
        }

        if ((_temperatureState == DP_TEMPERATURE_LEVEL.T_HIGHER_RANGE) &&
            (_curTemper < (_temperatureHighAlertThr - DP_TEMPER_HYST)) &&
            (_curTemper > _temperatureLowAlertThr)) {
            _temperatureState = DP_TEMPERATURE_LEVEL.T_IN_RANGE;
        }

        if (_curTemper < _temperatureLowAlertThr &&
            _curTemper != DP_INIT_TEMPER_VALUE) {
            if (_temperatureState != DP_TEMPERATURE_LEVEL.T_BELOW_RANGE) {
                _allAlerts.temperatureLow = true;
                _temperatureState = DP_TEMPERATURE_LEVEL.T_BELOW_RANGE;

                ledIndication && ledIndication.indicate(LI_EVENT_TYPE.ALERT_TEMP_LOW);
            }
        }

        if ((_temperatureState == DP_TEMPERATURE_LEVEL.T_BELOW_RANGE) &&
            (_curTemper > (_temperatureLowAlertThr + DP_TEMPER_HYST)) &&
            (_curTemper < _temperatureHighAlertThr)) {
            _temperatureState = DP_TEMPERATURE_LEVEL.T_IN_RANGE;
        }
    }

    /**
     *  Read battery level, check alert conditions
     */
    function _checkBatteryVoltLevel() {
        // get the current battery level, check alert conditions - TODO
        if (_curBatteryLev < _batteryLowThr &&
            _curBatteryLev != DP_INIT_BATTERY_LEVEL) {
                if (_batteryState == DP_BATTERY_VOLT_LEVEL.V_IN_RANGE) {
                    _allAlerts.batteryLow = true;
                    _batteryState = DP_BATTERY_VOLT_LEVEL.V_NOT_IN_RANGE;
                }
        }

        if (_curBatteryLev > (_batteryLowThr + DP_BATTERY_LEV_HYST)) {
            _batteryState = DP_BATTERY_VOLT_LEVEL.V_IN_RANGE;
        }
    }

    /**
     *  The handler is called when a new location is received.
     *  @param {table} loc - Location information.
     *      The fields:
     *          "timestamp": {integer}  - Time value
     *               "type": {string}   - gnss or cell e.g.
     *           "accuracy": {integer}  - Accuracy in meters
     *          "longitude": {float}    - Longitude in degrees
     *           "latitude": {float}    - Latitude in degrees
     */
    function _onNewLocation(loc) {
        if (loc && typeof loc == "table") {
            _currentLocation = loc;
        } else {
            ::error("Error type of location value", "DataProcessor");
        }
    }

    /**
     *  The handler is called when a new battery level is received.
     *  @param {float} lev - Сharge level in percent.
     */
    function _onNewBatteryLevel(lev) {
        if (lev && typeof lev == "float") {
            _curBatteryLev = lev;
        } else {
            ::error("Error type of battery level", "DataProcessor");
        }
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
            _inMotion = true;

            ledIndication && ledIndication.indicate(LI_EVENT_TYPE.ALERT_MOTION_STARTED);
        } else {
            _allAlerts.motionStopped = true;
            _inMotion = false;

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
}

//line 40 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/Main.device.nut"

//line 2 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/LocationDriver.device.nut"

// GNSS options:
// Accuracy threshold of positioning, in meters
const LD_GNSS_ACCURACY = 30;
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
    // UBloxM8N instance
    _ubxDriver = null;
    // UBloxAssistNow instance
    _ubxAssist = null;
    // SPIFlashFileSystem instance. Used to store u-blox assist data
    _assistDataStorage = null;
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
    // ESP32 object
    _esp = null;
    // Known BLE devices
    _knownBLEDevices = null;

    /**
     * Constructor for Location Driver
     */
    constructor() {
        _knownBLEDevices = DEFAULT_BLE_DEVICES;

        _ubxDriver = UBloxM8N(HW_UBLOX_UART);
        local ubxSettings = {
            "baudRate"     : LD_UBLOX_UART_BAUDRATE,
            "outputMode"   : UBLOX_M8N_MSG_MODE.UBX_ONLY,
            // TODO: Why BOTH?
            "inputMode"    : UBLOX_M8N_MSG_MODE.BOTH
        };


        _ubxDriver.configure(ubxSettings);
        _ubxAssist = UBloxAssistNow(_ubxDriver);

        _assistDataStorage = SPIFlashFileSystem(HW_LD_SFFS_START_ADDR, HW_LD_SFFS_END_ADDR);
        _assistDataStorage.init();

        cm.onConnect(_onConnected.bindenv(this), "LocationDriver");
        _esp = ESP32Driver(HW_ESP_POWER_EN_PIN, HW_ESP_UART);
        _updateAssistData();
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
            ::info("Couldn't get location using BLE devices: " + err, "LocationDriver");
            return _getLocationGNSS();
        }.bindenv(this))
        .fail(function(err) {
            ::info("Couldn't get location using GNSS: " + err, "LocationDriver");
            return _getLocationCellTowersAndWiFi();
        }.bindenv(this))
        .then(function(location) {
            _gettingLocation = null;
            return location;
        }.bindenv(this), function(err) {
            ::info("Couldn't get location using WiFi networks and cell towers: " + err, "LocationDriver");
            _gettingLocation = null;
            return Promise.reject(null);
        }.bindenv(this));
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

        return _updateAssistData()
        .finally(function(_) {
            // TODO: Power on the module?
            ::debug("Writing the UTC time to u-blox..", "LocationDriver");
            _ubxAssist.writeUtcTimeAssist();
            return _writeAssistDataToUBlox();
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
                _ubxDriver.enableUbxMsg(UBX_MSG_PARSER_CLASS_MSG_ID.NAV_PVT, LD_UBLOX_LOC_CHECK_PERIOD, _onUBloxNavMsgFunc(onFix));
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
            scannedWifis = wifis;
        }.bindenv(this), function(err) {
            ::error("Couldn't scan WiFi networks: " + err, "LocationDriver");
        }.bindenv(this));

        return cm.connect()
        .then(function(_) {
            scannedTowers = BG96CellInfo.scanCellTowers();
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
        ::debug("Getting location using BLE devices..", "LocationDriver");
        // Default accuracy
        const LD_BLE_BEACON_DEFAULT_ACCURACY = 10;

        return _esp.scanBLEAdverts()
        .then(function(adverts) {
            local knownGeneric = _knownBLEDevices.generic;
            local knownIBeacons = _knownBLEDevices.iBeacon;
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
                    local iBeaconInfo = format("UUID %s, Major %d, Minor %d", _formatUUID(parsed.uuid), parsed.major, parsed.minor);
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
     *     "major" : {integer} - Major (from 0 to 65535).
     *     "minor" : {integer} - Minor (from 0 to 65535).
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
            "uuid": data.readblob(16).tostring(),
            "major": (data.readn('b') << 8) | data.readn('b'),
            "minor": (data.readn('b') << 8) | data.readn('b'),
        }
    }

    // -------------------- UBLOX-SPECIFIC METHODS -------------------- //

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
                // TODO: Check if this can be printed and read ok
                ::error(parsed.error, "LocationDriver");
                ::debug("The full payload containing the error: " + payload, "LocationDriver");
                return;
            }


            // Check fixtype
            if (parsed.fixType >= LD_UBLOX_FIX_TYPE.FIX_3D) {
                local accuracy = _getUBloxAccuracy(parsed.hAcc);

                if (accuracy <= LD_GNSS_ACCURACY) {
                    onFix({
                        // If we don't have the valid time, we take it from the location data
                        "timestamp": time() > LD_VALID_TS ? time() : _dateToTimestamp(parsed),
                        "type": "gnss",
                        "accuracy": accuracy,
                        "longitude": parsed.lon,
                        "latitude": parsed.lat
                    });
                }
            }
        }.bindenv(this);
    }

    /**
     * Disable u-blox navigation messages
     * TODO: And power off the u-blox module?
     */
    function _disableUBlox() {
        ::debug("Disable u-blox navigation messages...", "LocationDriver._disableNavMsgs");
        // Disable Position Velocity Time Solution messages
        _ubxDriver.enableUbxMsg(UBX_MSG_PARSER_CLASS_MSG_ID.NAV_PVT, 0);

        // TODO: Power off the module?
    }

    /**
     * Write the applicable u-blox assist data (if any) saved in the storage to the u-blox module
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function _writeAssistDataToUBlox() {
        return Promise(function(resolve, reject) {
            local assistData = _readUBloxAssistData();
            if (assistData == null) {
                return reject(null);
            }

            local onDone = function(errors) {
                // TODO: Temporarily print this log message as we have never seen this
                // callback called and want to be aware if it is suddenly called one day
                ::info("ATTENTION!!! U-BLOX WRITE-ASSIST-DATA CALLBACK HAS BEEN CALLED!");

                if (!errors) {
                    ::debug("Assist data has been written to u-blox successfully", "LocationDriver");
                    return resolve(null);
                }

                ::error("Errors during u-blox assist data writing:", "LocationDriver");
                foreach(err in errors) {
                    // Log errors encountered
                    ::error(err, "LocationDriver");
                }

                reject(null);
            }.bindenv(this);

            ::debug("Writing assist data to u-blox..", "LocationDriver");
            _ubxAssist.writeAssistNow(assistData, onDone);

            // TODO: Temporarily resolve this Promise immediately because for some reason,
            // the callback is not called by the writeAssistNow() method
            resolve(null);
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

            if (_assistDataStorage.fileExists(todayFileName)) {
                chosenFile = todayFileName;
            } else if (_assistDataStorage.fileExists(tomorrowFileName)) {
                chosenFile = tomorrowFileName;
            } else if (_assistDataStorage.fileExists(yesterdayFileName)) {
                chosenFile = yesterdayFileName;
            }

            if (chosenFile == null) {
                ::debug("No applicable u-blox assist data found", "LocationDriver");
                return null;
            }

            ::debug("Found applicable u-blox assist data with the following date: " + chosenFile, "LocationDriver");

            local file = _assistDataStorage.open(chosenFile, "r");
            local data = file.read();
            file.close();
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

        try {
            foreach (date, assistMsgs in data) {
                // Erase the existing file if any
                if (_assistDataStorage.fileExists(date)) {
                    _assistDataStorage.eraseFile(date);
                }

                local file = _assistDataStorage.open(date, "w");
                file.write(assistMsgs);
                file.close();
            }
        } catch (err) {
            ::error("Couldn't save u-blox assist data: " + err, "LocationDriver");
        }
    }

    /**
     * Erase stale u-blox assist data from the storage
     */
    function _eraseStaleUBloxAssistData() {
        ::debug("Erasing stale u-blox assist data..", "LocationDriver");

        try {
            local files = _assistDataStorage.getFileList();
            // Since the date has the following format YYYYMMDD, we can compare dates as integer numbers
            local yesterday = UBloxAssistNow.getDateString(date(time() - LD_DAY_SEC)).tointeger();

            foreach (file in files) {
                local name = file.fname;
                local erase = true;

                try {
                    // We need to find assist files for dates before yesterday
                    local fileDate = name.tointeger();

                    erase = fileDate < yesterday;
                } catch (err) {
                    ::error("Couldn't check the date of a u-blox assist data file: " + err, "LocationDriver");
                }

                if (erase) {
                    ::debug("Erasing u-blox assist data file: " + name, "LocationDriver");
                    // Erase stale assist message
                    _assistDataStorage.eraseFile(name);
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

    /**
     * Format a UUID string to make it printable and human-readable
     *
     * @param {string} str - UUID string (16 bytes)
     *
     * @return {string} Printable and human-readable UUID string
     *  The format is: 00112233-4455-6677-8899-aabbccddeeff
     */
    function _formatUUID(str) {
        // The indexes where the dash character ("-") must be placed in the UUID representation
        local uuidDashes = [3, 5, 7, 9];
        local res = "";

        for (local i = 0; i < str.len(); i++) {
            res += format("%02x", str[i]);
            if (uuidDashes.find(i) != null) {
                res += "-";
            }
        }

        return res;
    }
}

//line 46 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/device/Main.device.nut"

// Main application on Imp-Device: does the main logic of the application

// Connection Manager configuration constants:
// Maximum time allowed for the imp to connect to the server before timing out, in seconds
const APP_CM_CONNECT_TIMEOUT = 180.0;
// Delay before automatic disconnection if there are no connection consumers, in seconds
const APP_CM_AUTO_DISC_DELAY = 10.0;
// Maximum time allowed for the imp to be connected to the server, in seconds
const APP_CM_MAX_CONNECTED_TIME = 300.0;

// Replay Messenger configuration constants:
// The maximum message send rate,
// ie. the maximum number of messages the library allows to be sent in a second
const APP_RM_MSG_SENDING_MAX_RATE = 5;
// The maximum number of messages to queue at any given time when replaying
const APP_RM_MSG_RESEND_LIMIT = 5;

// Send buffer size, in bytes
const APP_SEND_BUFFER_SIZE = 10240;

// TODO: Check the RAM consumption!
class Application {
    _locationDriver = null;
    _accelDriver = null;
    _motionMon = null;
    _dataProc = null;
    _thermoSensDriver = null;

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
        ::debug("Wake reason: " + hardware.wakereason());

        ledIndication = LedIndication(HW_LED_RED_PIN, HW_LED_GREEN_PIN, HW_LED_BLUE_PIN);

        // Create and intialize Replay Messenger
        _initReplayMessenger()
        .then(function(_) {
            // Create and initialize Location Driver
            _locationDriver = LocationDriver();

            // Create and initialize Accelerometer Driver
            _accelDriver = AccelerometerDriver(HW_ACCEL_I2C, HW_ACCEL_INT_PIN);

            // Create and initialize Thermosensor Driver
            _thermoSensDriver = HTS221(HW_TEMPHUM_SENSOR_I2C);
            _thermoSensDriver.setMode(HTS221_MODE.ONE_SHOT);

            // Create and initialize Motion Monitor
            _motionMon = MotionMonitor(_accelDriver, _locationDriver);
            // Create and initialize Data Processor
            _dataProc = DataProcessor(_motionMon, _accelDriver, _thermoSensDriver, null);
            // Start Data processor
            _dataProc.start();
            // Start Motion monitor
            _motionMon.start();
        }.bindenv(this), function(err) {
            ::error("Replay Messenger initialization error: " + err);
        }.bindenv(this))
        .fail(function(err) {
            ::error("Error during initialization of business logic modules: " + err);

            // TODO: Reboot after a delay? Or enter the emergency mode?
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
}

// ---------------------------- THE MAIN CODE ---------------------------- //

// Connection Manager, controls connection with Imp-Agent
cm <- null;

// Replay Messenger, communicates with Imp-Agent
rm <- null;

// LED indication
ledIndication <- null;

// Callback to be called by Production Manager if it allows to run the main application
function startApp() {
    // Run the application
    ::app <- Application();
}

pm <- ProductionManager(startApp);
pm.start();
//line 7 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/not_for_uploading/my_main.device.nut"

