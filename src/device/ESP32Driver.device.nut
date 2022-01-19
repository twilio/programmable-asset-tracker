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

    /**
     * Constructor for ESP32 Driver Class
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

        // enable 3.3V to microBUS
        if (_enable3VPin) {
            _enable3VPin.configure(DIGITAL_OUT, 1);
        } else {
            throw "Hardware pin object is null.";
        }

        // configure UART
        if (_serial) {
            _serial.setrxfifosize(_settings.rxFifoSize);
            _serial.configure(_settings.baudRate, 
                              _settings.wordSize, 
                              _settings.parity, 
                              _settings.stopBits, 
                              _settings.flags, 
                              _rxCb.bindenv(this));
        } else {
            throw "UART object is null.";
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

        local atRestoreReq = function() {
            return function() {
                return Promise(function(resolve, reject) {
                    _resp = "";
                    local req = "AT+RESTORE\r\n";
                    _parseATResponceCb = function() {
                        if (_resp.len() > req.len()) {
                            if (_resp.find("OK")) {
                                resolve("OK");
                            } else {
                                reject("Error AT+RESTORE command");
                            }
                        }
                    }.bindenv(this);
                    _serial.write(req);
                    imp.sleep(3);
                }.bindenv(this));
            }.bindenv(this);
        }

        local atVersionReq = function() {
            return function() {
                return Promise(function(resolve, reject) {
                    _resp = "";
                    local req = "AT+GMR\r\n";
                    _parseATResponceCb = function() {
                        if (_resp.len() > req.len()) {
                            if (_resp.find("OK")) {
                                local respStrArr = split(_resp, "\r\n");
                                ::info("ESP AT software:", "@{CLASS_NAME}");
                                foreach (ind, el in respStrArr) {
                                    if (ind != 0 && ind != (respStrArr.len() - 1)) {
                                        ::info(el, "@{CLASS_NAME}");
                                    }
                                }
                                resolve("OK");
                            } else {
                                reject("Error check version");
                            }
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
                        if (_resp.len() > req.len()) {
                            if (_resp.find("OK")) {
                                resolve("OK");
                            } else {
                                reject("Error set WiFi mode");
                            }
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
                        if (_resp.len() > req.len()) {
                            if (_resp.find("OK")) {
                                resolve("OK");
                            } else {
                                reject("Error set WiFi scan print mask info");
                            }
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
            local req = "AT+CWLAP\r\n";
            _parseATResponceCb = function() {
                if (_resp.len() > req.len()) {
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
                                            ::error("Unknown index", "@{CLASS_NAME}");
                                            break;
                                    }      
                                }
                                scanRes.push(scanResEl);
                            }
                        }
                        resolve(scanRes);
                    } else {
                        reject("Error scan WiFi");
                    }
                }
            }.bindenv(this);
            _serial.write(req);
            imp.sleep(3);
        }.bindenv(this));
    }

    // -------------------- PRIVATE METHODS -------------------- //

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