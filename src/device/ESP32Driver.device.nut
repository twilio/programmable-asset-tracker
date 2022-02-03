@set CLASS_NAME = "ESP32Driver" // Class name for logging

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

// Enum for init steps 
enum ESP32_INIT_STEP {
    RESTORE = 0,
    GMR = 1,
    CWMODE = 2,
    CWLAPOPT = 3
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

    // init flag
    _isInit = null;

    // Reject timer
    _rejTimer = null;

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

        _isInit = false;
        _resp = "";
        _msgWaitStart = time();
        _devReady = false;
        // enable 3.3V to microBUS
        if (_enable3VPin) {
            // configure (power off)
            _enable3VPin.configure(DIGITAL_OUT, ESP32_POWER.OFF);
            imp.sleep(0.1);
            // power on
            _enable3VPin.write(ESP32_POWER.ON);
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
        ::debug("Scan WiFi networks", "@{CLASS_NAME}");
        return _init()
        .then(function(initStatus) {
            ::debug("Init status: " + initStatus, "@{CLASS_NAME}");
            return Promise(function(resolve, reject) {
                local scanRes = [];
                _resp = "";
                _msgWaitStart = time();
                local req = "AT+CWLAP\r\n";
                // create reject timer
                if (_rejTimer == null) {
                    _rejTimer = imp.wakeup(ESP32_MAX_MSG_WAIT_DELAY, function() {
                        reject("Error scan WiFi");    
                    }.bindenv(this));
                }
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
                                            // remove "
                                            scanResEl.ssid = _removeQuotMark(paramEl);
                                            break;
                                        case ESP32_PARAM_ORDER.RSSI:
                                            scanResEl.rssi = paramEl.tointeger();
                                            break;
                                        case ESP32_PARAM_ORDER.MAC:
                                            // remove : and "
                                            local macAddrArr = split(paramEl, ":");
                                            local resMac = "";
                                            foreach (el in macAddrArr) {
                                                resMac += el;
                                            }
                                            scanResEl.bssid = _removeQuotMark(resMac);
                                            break;
                                        case ESP32_PARAM_ORDER.CHANNEL:
                                            scanResEl.channel = paramEl.tointeger();
                                            break;
                                        default:
                                            ::error("Unknown index", "@{CLASS_NAME}");
                                            break;
                                    }
                                }
                                // push if element not null
                                if (scanResEl.bssid && scanResEl.channel && scanResEl.rssi) {
                                    scanRes.push(scanResEl);
                                }
                            }
                        }
                        if (_rejTimer) {
                            imp.cancelwakeup(_rejTimer);
                            _rejTimer = null;
                        }
                        resolve(scanRes);
                    }
                }.bindenv(this);
                _serial.write(req);
            }.bindenv(this));
        }.bindenv(this));
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Init and configure ESP32.
     *  
     * @param {bool} repeatInit - Clear last success init flag, and repeat init procedure.
     *      Optional, default value is false.
     *
     * @return {Promise} that:
     * - resolves with the init status of the click board
     * - rejects if the operation failed
     */
    function _init(repeatInit = false) {
        local funcArr = array();
        // init only if device is ready
        if (!_devReady) {
            return Promise.reject("ESP not ready");
        }
        // clear init flag on demand
        if (repeatInit) {
            _isInit = false;
        }

        if (_isInit) {
            ::debug("Already init", "@{CLASS_NAME}");
            return Promise.resolve("OK");
        }

        _serial.configure(_settings.baudRate, 
                          _settings.wordSize, 
                          _settings.parity, 
                          _settings.stopBits, 
                          _settings.flags,
                          _rxCb.bindenv(this));

        local reqCWMODE = format("AT+CWMODE=%d\r\n", ESP32_WIFI_MODE.STATION);
        local reqPRINTMASK = format("AT+CWLAPOPT=0,%d\r\n", 
                                    ESP32_WIFI_SCAN_PRINT_MASK.SHOW_SSID |
                                    ESP32_WIFI_SCAN_PRINT_MASK.SHOW_MAC |
                                    ESP32_WIFI_SCAN_PRINT_MASK.SHOW_CHANNEL |
                                    ESP32_WIFI_SCAN_PRINT_MASK.SHOW_RSSI |
                                    ESP32_WIFI_SCAN_PRINT_MASK.SHOW_ECN);
        local reqArr = [{"reqStr" : "AT+RESTORE\r\n",   "rejStr" : "Error AT+RESTORE command"},
                        {"reqStr" : "AT+GMR\r\n",       "rejStr" : "Error check version"},
                        {"reqStr" : reqCWMODE,          "rejStr" : "Error set WiFi mode"},
                        {"reqStr" : reqPRINTMASK,       "rejStr" : "Error set WiFi scan print mask info"}];

        local atFuncReq = function(reqNum) {
            return function() {
                return Promise(function(resolve, reject) {
                    _resp = "";
                    _msgWaitStart = time();
                    local req = reqArr[reqNum].reqStr;
                    if (_rejTimer == null) {
                        _rejTimer = imp.wakeup(ESP32_MAX_MSG_WAIT_DELAY, function() {
                            reject(reqArr[reqNum].rejStr);
                        }.bindenv(this));
                    }
                    _parseATResponceCb = function() {
                        local resCheck = null;
                        if (reqNum == ESP32_INIT_STEP.RESTORE) {
                            resCheck = (_resp.find("OK")  && _resp.find("ready"));
                        } else {
                            resCheck = _resp.find("OK");
                        }
                        if (resCheck) {
                            // print version info
                            if (reqNum == ESP32_INIT_STEP.GMR) {
                                local respStrArr = split(_resp, "\r\n");
                                ::info("ESP AT software:", "@{CLASS_NAME}");
                                foreach (ind, el in respStrArr) {
                                    if (ind != 0 && ind != (respStrArr.len() - 1)) {
                                        ::info(el, "@{CLASS_NAME}");
                                    }
                                }    
                            }
                            // init flag -> true
                            if (reqNum == ESP32_INIT_STEP.CWLAPOPT) {
                                _isInit = true;    
                            }
                            if (_rejTimer) {
                                imp.cancelwakeup(_rejTimer);
                                _rejTimer = null;
                            }
                            resolve("OK");
                        }
                    }.bindenv(this);
                    _serial.write(req);
                }.bindenv(this));    
            }.bindenv(this);
        }

        foreach (id, el in reqArr) {
            funcArr.push(atFuncReq(id));
        }

        local promises = Promise.serial(funcArr);
        return promises;
    }

    /**
     * Remove "".
     */
    function _removeQuotMark(paramStr) {
        local paramLen = paramStr.len();
        if (paramLen > 2) {// "param str" -> param str
            return paramStr.slice(1, paramLen - 1);
        }

        return "";
    } 

    /**
     * Wait ready of ESP.
     */
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
            ::error("Incorrect type of settings parameter", "@{CLASS_NAME}");
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
                        ::error("Incorrect key name", "@{CLASS_NAME}");
                        break;
                }
            } else {
                ::error("Incorrect key type", "@{CLASS_NAME}");
            }
        }
    }
}

@set CLASS_NAME = null // Reset the variable