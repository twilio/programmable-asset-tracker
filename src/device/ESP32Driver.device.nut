@set CLASS_NAME = "ESP32Driver" // Class name for logging

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
const ESP32_MAX_DATA_LEN = 6144;
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
const ESP32_BLE_SCAN_PERIOD = 2;

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
            ::debug("Scanning WiFi networks..", "@{CLASS_NAME}");

            local okValidator = @(data, _) data.find("\r\nOK\r\n") != null;
            // Send "List Available APs" cmd and parse the result
            return _communicate("AT+CWLAP", okValidator, _parseWifiNetworks, false);
        }.bindenv(this))
        .then(function(wifis) {
            ::debug("Scanning of WiFi networks finished successfully. Scanned items: " + wifis.len(), "@{CLASS_NAME}");
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
            ::debug("Scanning BLE advertisements..", "@{CLASS_NAME}");

            local bleScanCmd = format("AT+BLESCAN=%d,%d", ESP32_BLE_SCAN.ENABLE, ESP32_BLE_SCAN_PERIOD);
            local validator = @(data, timeElapsed) (data.find("\r\nOK\r\n") != null &&
                                                    timeElapsed >= ESP32_BLE_SCAN_PERIOD);
            // Send "Enable Bluetooth LE Scanning" cmd and parse the result
            return _communicate(bleScanCmd, validator, _parseBLEAdverts, false);
        }.bindenv(this))
        .then(function(adverts) {
            ::debug("Scanning of BLE advertisements finished successfully. Scanned items: " + adverts.len(), "@{CLASS_NAME}");
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
            ::info("BLE scan period is greater than wait data period!", "@{CLASS_NAME}");
        }

        ::debug("Starting initialization", "@{CLASS_NAME}");

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
            ::debug("Initialization complete", "@{CLASS_NAME}");
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
            ::debug(format("Sending %s cmd..", cmd), "@{CLASS_NAME}");
            _serial.write(cmd + "\r\n");
        }

        return _waitForData(validator)
        .then(function(reply) {
            cmd && ::debug(format("Reply for %s cmd received", cmd), "@{CLASS_NAME}");
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

        ::debug("ESP32 board has been switched ON", "@{CLASS_NAME}");
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

        ::debug("ESP32 board has been switched OFF", "@{CLASS_NAME}");
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

        ::debug("Parsing the WiFi scan response..", "@{CLASS_NAME}");

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

        ::debug("ESP AT software:", "@{CLASS_NAME}");

        try {
            local rows = split(data, "\r\n");
            for (local i = 1; i < rows.len() - 1; i++) {
                ::debug(rows[i], "@{CLASS_NAME}");
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
        ::debug("Parsing the BLE devices scan response..", "@{CLASS_NAME}");

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

@set CLASS_NAME = null // Reset the variable
