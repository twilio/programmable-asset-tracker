//line 1 "/home/we/Develop/Squirrel/prog-x/tests/ESP32DriverTest.device.nut"
#require "Promise.lib.nut:4.0.0"

//line 1 "../src/shared/Logger/Logger.shared.nut"
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

//line 2 "../src/device/ESP32Driver.device.nut"

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

// Enum for WiFi network parameter order 
enum ESP32_PARAM_ORDER {
    ECN = 0,
    SSID = 1,
    RSSI = 2,
    MAC = 3,
    CHANNEL = 4
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
const ESP32_DEFAULT_RX_FIFO_SZ = 800;
// Max ready wait time, in seconds
const ESP32_MAX_READY_WAIT_DELAY = 8;
// Max message response wait time, in seconds
const ESP32_MAX_MSG_WAIT_DELAY = 8;


// ESP32 Driver class.
// Ability to work with WiFi networks and BLE.
class ESP32Driver {

    // enable load switch pin
    _enable3VPin = null;

    // uart object
    _serial = null;

    // all settings
    _settings = null;

    // parse AT command response callback
    _parseATResponceCb = null;

    // response string
    _resp = null;

    // time stamp on start
    _msgWaitStart = null;

    // ready flag (init success, device ready)
    _devReady = null;

    /**
     * Constructor for ESP32 Driver Class.
     * (constructor wait the ready message from ESP, max. wait - ESP32_MAX_READY_WAIT_DELAY)
     *
     * @param {object} enPin - Hardware pin object connected to load switch (1 - enable 3.3V to microBUS)
     * @param {object} uart - UART object connected to click board on microBUS
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
    constructor(enPin, uart, settings = {}) {
        _enable3VPin = enPin;
        _serial = uart;

        // Set default settings
        _settings = {
            "baudRate"  : ESP32_DEFAULT_BAUDRATE,
            "wordSize"  : ESP32_DEFAULT_WORD_SIZE,
            "parity"    : ESP32_DEFAULT_PARITY,
            "stopBits"  : ESP32_DEFAULT_STOP_BITS,
            "flags"     : ESP32_DEFAULT_FLAGS,
            "rxFifoSize": ESP32_DEFAULT_RX_FIFO_SZ
        };

        if (settings != null) {
            _checkSettings(settings);
        }

        // configure UART
        if (_serial) {
            _serial.setrxfifosize(_settings.rxFifoSize);
            _serial.configure(_settings.baudRate, 
                              _settings.wordSize, 
                              _settings.parity, 
                              _settings.stopBits, 
                              _settings.flags);
        } else {
            throw "UART object is null.";
        }

        _resp = "";
        _msgWaitStart = time();
        _devReady = false;
        // enable 3.3V to microBUS
        if (_enable3VPin) {
            _enable3VPin.configure(DIGITAL_OUT, 1);
        } else {
            throw "Hardware pin object is null.";
        }
        // wait ready
        while((time() - _msgWaitStart < ESP32_MAX_READY_WAIT_DELAY)) {
            if (_waitReady()) {
                _devReady = true;
                break;
            }
            imp.sleep(0.5);
        }
    }

    /**
     * Init and configure ESP32.
     *  
     * @return {Promise} that:
     * - resolves with the init status of the click board
     * - rejects if the operation failed
     */
    function init() {
        local funcArr = array();

        if (!_devReady) {
            return Promise.reject("ESP not ready");
        }

        _serial.configure(_settings.baudRate, 
                          _settings.wordSize, 
                          _settings.parity, 
                          _settings.stopBits, 
                          _settings.flags,
                          _rxCb.bindenv(this));

        local atRestoreReq = function() {
            return function() {
                return Promise(function(resolve, reject) {
                    _resp = "";
                    _msgWaitStart = time();
                    local req = "AT+RESTORE\r\n";
                    _parseATResponceCb = function() {
                        if (_resp.find("OK")  && _resp.find("ready")) {
                            resolve("OK");
                        } else {
                            if ((time() - _msgWaitStart) > ESP32_MAX_READY_WAIT_DELAY) {
                                reject("Error AT+RESTORE command");
                            }
                        }
                    }.bindenv(this);
                    _serial.write(req);
                }.bindenv(this));
            }.bindenv(this);
        }

        local atVersionReq = function() {
            return function() {
                return Promise(function(resolve, reject) {
                    _resp = "";
                    local req = "AT+GMR\r\n";
                    _parseATResponceCb = function() {
                        if (_resp.find("OK")) {
                            local respStrArr = split(_resp, "\r\n");
                            ::info("ESP AT software:", "ESP32Driver");
                            foreach (ind, el in respStrArr) {
                                if (ind != 0 && ind != (respStrArr.len() - 1)) {
                                    ::info(el, "ESP32Driver");
                                }
                            }
                            resolve("OK");
                        } else {
                            reject("Error check version");
                        }
                    }.bindenv(this);
                    _serial.write(req);
                    imp.sleep(3);
                }.bindenv(this));
            }.bindenv(this);
        }

        local atSetModeReq = function() {
            return function() {
                return Promise(function(resolve, reject) {
                    _resp = "";
                    local req = format("AT+CWMODE=%d\r\n", ESP32_WIFI_MODE.STATION);
                    _parseATResponceCb = function() {
                        if (_resp.find("OK")) {
                            resolve("OK");
                        } else {
                            reject("Error set WiFi mode");
                        }
                    }.bindenv(this);
                    _serial.write(req);
                    imp.sleep(3);
                }.bindenv(this));
            }.bindenv(this);
        }

        local atConfigureScanInfoReq = function() {
            return function() {
                return Promise(function(resolve, reject) {
                    _resp = "";
                    local req = format("AT+CWLAPOPT=0,%d\r\n", 
                                       ESP32_WIFI_SCAN_PRINT_MASK.SHOW_SSID |
                                       ESP32_WIFI_SCAN_PRINT_MASK.SHOW_MAC |
                                       ESP32_WIFI_SCAN_PRINT_MASK.SHOW_CHANNEL |
                                       ESP32_WIFI_SCAN_PRINT_MASK.SHOW_RSSI |
                                       ESP32_WIFI_SCAN_PRINT_MASK.SHOW_ECN);
                    _parseATResponceCb = function() {
                        if (_resp.find("OK")) {
                            resolve("OK");
                        } else {
                            reject("Error set WiFi scan print mask info");
                        }
                    }.bindenv(this);
                    _serial.write(req);
                    imp.sleep(3);
                }.bindenv(this));
            }.bindenv(this);
        }

        funcArr.push(atRestoreReq());
        funcArr.push(atVersionReq());
        funcArr.push(atSetModeReq());
        funcArr.push(atConfigureScanInfoReq());

        local promises = Promise.serial(funcArr);
        return promises;
    }

    /**
     * Scan WiFi networks.
     *  
     * @return {Promise} that:
     * - resolves with the table array of WiFi networks detectable by the click board
     * The result array element table format:
     *      "ssid"      : {string}  - SSID (network name).
     *      "bssid"     : {string}  - BSSID (access point’s MAC address), in 0123456789ab format.
     *      "channel"   : {integer} - Channel number: 1-13 (2.4GHz).
     *      "rssi"      : {integer} - RSSI (signal strength).
     *      "open"      : {bool}    - Whether the network is open (password-free).
     * - rejects if the operation failed
     */
    function scanWiFiNetworks() {
        return Promise(function(resolve, reject) {
            local scanRes = [];
            _resp = "";
            _msgWaitStart = time();
            local req = "AT+CWLAP\r\n";
            _parseATResponceCb = function() {
                if (_resp.find("OK")) {
                    local scanResRawArr = split(_resp, "\r\n");
                    foreach (el in scanResRawArr) {
                        local paramStartPos = el.find("(");
                        local paramEndPos = el.find(")");
                        local scanResEl = {"ssid"   : null,
                                           "bssid"  : null,
                                           "channel": null,
                                           "rssi"   : null,
                                           "open"   : null};
                        if (paramStartPos && paramEndPos) {
                            local networks = split(el.slice(paramStartPos + 1, paramEndPos), ",");
                            foreach (ind, paramEl in networks) {
                                switch(ind) {
                                    case ESP32_PARAM_ORDER.ECN:
                                        scanResEl.open = paramEl.tointeger() == ESP32_ECN_METHOD.OPEN ? true : false;
                                        break;
                                    case ESP32_PARAM_ORDER.SSID:
                                        scanResEl.ssid = paramEl;
                                        break;
                                    case ESP32_PARAM_ORDER.RSSI:
                                        scanResEl.rssi = paramEl.tointeger();
                                        break;
                                    case ESP32_PARAM_ORDER.MAC:
                                        // remove ":"
                                        local macAddrArr = split(paramEl, ":");
                                        local resMac = "";
                                        foreach (el in macAddrArr) {
                                            resMac += el;
                                        }
                                        scanResEl.bssid = resMac;
                                        break;
                                    case ESP32_PARAM_ORDER.CHANNEL:
                                        scanResEl.channel = paramEl.tointeger();
                                        break;
                                    default:
                                        ::error("Unknown index", "ESP32Driver");
                                        break;
                                }
                            }
                            scanRes.push(scanResEl);
                        }
                    }
                    resolve(scanRes);
                } else {
                    if ((time() - _msgWaitStart) > ESP32_MAX_MSG_WAIT_DELAY) {
                        reject("Error scan WiFi");
                    }
                }
            }.bindenv(this);
            _serial.write(req);
        }.bindenv(this));
    }

    // -------------------- PRIVATE METHODS -------------------- //

    function _waitReady() {
        local data = _serial.read();
        // read until FIFO not empty and accumulate to result string
        while (data != -1) {
            _resp += data.tochar();
            data = _serial.read();
        }

        return _resp.find("ready");
    }

    /**
     * Callback function on data received.
     */
    function _rxCb() {
        local data = _serial.read();
        // read until FIFO not empty and accumulate to result string
        while (data != -1) {
            _resp += data.tochar();
            data = _serial.read();
        }

        if (_isFunction(_parseATResponceCb)) {
            _parseATResponceCb();
        }
    }

    /**
     * Check object for callback function set method.
     * @param {function} f - Callback function.
     * @return {boolean} true if argument is function and not null.
     */
    function _isFunction(f) {
        return f && typeof f == "function";
    }

    /**
     * Check settings element.
     * Returns the specified value if the check fails.
     *
     * @param {integer} val - Value of settings element.
     * @param {integer} defVal - Default value of settings element.
     *
     * @return {integer} If success - value, else - default value.
     */
    function _checkVal(val, defVal) {
        if (typeof val == "integer") {
                return val;
        } else {
            ::error("Incorrect type of settings parameter", "ESP32Driver");
        }

        return defVal;
    }

    /**
     *  Check and set settings.
     *  Sets default values for incorrect settings.
     *
     *   @param {table} settings - Table with the settings.
     *        Optional, all settings have defaults.
     *        The settings:
     *              "baudRate"  : {integer} - UART baudrate, in baud per second.
     *                                          Default: ESP32_DEFAULT_BAUDRATE
     *              "wordSize"  : {integer} - Word size, in bits.
     *                                          Default: ESP32_DEFAULT_WORD_SIZE
     *              "parity"    : {integer} - Parity.
     *                                          Default: ESP32_DEFAULT_PARITY
     *              "stopBits"  : {integer} - Count of stop bits.
     *                                          Default: ESP32_DEFAULT_STOP_BITS
     *              "flags"     : {integer} - Control flags.
     *                                          Default: ESP32_DEFAULT_FLAGS
     *              "rxFifoSize": {integer} - The new size of the receive FIFO, in bytes.
     *                                          Default: ESP32_DEFAULT_RX_FIFO_SZ
     */
    function _checkSettings(settings) {
        foreach (key, value in settings) {
            if (typeof key == "string") {
                switch(key) {
                    case "baudRate":
                        _settings.baudRate = _checkVal(value, ESP32_DEFAULT_BAUDRATE);
                        break;
                    case "wordSize":
                        _settings.wordSize = _checkVal(value, ESP32_DEFAULT_WORD_SIZE);
                        break;
                    case "parity":
                        _settings.parity = _checkVal(value, ESP32_DEFAULT_PARITY);
                        break;
                    case "stopBits":
                        _settings.stopBits = _checkVal(value, ESP32_DEFAULT_STOP_BITS);
                        break;
                    case "flags":
                        _settings.flags = _checkVal(value, ESP32_DEFAULT_FLAGS);
                        break;
                    case "rxFifoSize":
                        _settings.rxFifoSize = _checkVal(value, ESP32_DEFAULT_RX_FIFO_SZ);
                        break;
                    default:
                        ::error("Incorrect key name", "ESP32Driver");
                        break;
                }
            } else {
                ::error("Incorrect key type", "ESP32Driver");
            }
        }
    }
}

//line 5 "/home/we/Develop/Squirrel/prog-x/tests/ESP32DriverTest.device.nut"

// new RX FIFO size
const ESP_DRV_TEST_RX_FIFO_SIZE = 800;

// UART settings
const ESP_DRV_TEST_BAUDRATE = 115200;
const ESP_DRV_TEST_BIT_IN_CHAR = 8;
const ESP_DRV_TEST_STOP_BITS = 1;
const ESP_DRV_TEST_PARITY_NONE = 0;
const ESP_DRV_TEST_NO_CRT_RTS = 4;

// scan WiFi period, in seconds
const ESP_DRV_TEST_SCAN_WIFI_PERIOD = 60;

server.log("ESP AT test");

function scan() {
    esp.scanWiFiNetworks().then(function(wifiNetworks) {
        server.log("Find "  + wifiNetworks.len() + " WiFi network:");
        foreach (ind, network in wifiNetworks) {
            local networkStr = format("%d) ", ind + 1);
            foreach (el, val in network) {
                networkStr += el + ": " + val + ", "
            }
            local networkStrLen = networkStr.len();
            // remove ", "
            server.log(networkStr.slice(0, networkStrLen - 2));
        }
    }).fail(function(error) {
        server.log("Scan WiFi network error: " + error);
    }).finally(function(_) {
        imp.wakeup(ESP_DRV_TEST_SCAN_WIFI_PERIOD, scan);
    });
}

Logger.setLogLevel(LGR_LOG_LEVEL.DEBUG);

// create ESP32 driver object
esp <- ESP32Driver(hardware.pinXU,
                   hardware.uartXEFGH,
                   {
                        "baudRate"  : ESP_DRV_TEST_BAUDRATE,
                        "wordSize"  : ESP_DRV_TEST_BIT_IN_CHAR,
                        "parity"    : ESP_DRV_TEST_PARITY_NONE,
                        "stopBits"  : ESP_DRV_TEST_STOP_BITS,
                        "flags"     : ESP_DRV_TEST_NO_CRT_RTS,
                        "rxFifoSize": ESP_DRV_TEST_RX_FIFO_SIZE
                   }
                );
server.log("ESP32 chip boot...");
// esp chip boot delay
server.log("init...");
// init and start scan
esp.init().then(function(initStatus) {
    server.log("Init status: " + initStatus);
    server.log("Scan WiFi network...");
    scan();
}).fail(function(error) {
    server.log("Init status: " + error);
});