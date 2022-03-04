@set CLASS_NAME = "LocationDriver" // Class name for logging

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
    // BLE beacons array
    _beaconsWithKnownLocation = null;

    /**
     * Constructor for Location Driver
     */
    constructor() {
        _ubxDriver = UBloxM8N(HW_UBLOX_UART);
        local ubxSettings = {
            "baudRate"     : LD_UBLOX_UART_BAUDRATE,
            "outputMode"   : UBLOX_M8N_MSG_MODE.UBX_ONLY,
            // TODO: Why BOTH?
            "inputMode"    : UBLOX_M8N_MSG_MODE.BOTH
        };

@if DEBUG_UBLOX
        // Register handlers with debug logging only if needed
        // Register command ACK and NAK callbacks
        _ubxDriver.registerOnMessageCallback(UBX_MSG_PARSER_CLASS_MSG_ID.ACK_ACK, _onUBloxACK.bindenv(this));
        _ubxDriver.registerOnMessageCallback(UBX_MSG_PARSER_CLASS_MSG_ID.ACK_NAK, _onUBloxNAK.bindenv(this));
        // Register general handler
        ubxSettings.defaultOnMsg <- _onUBloxMessage.bindenv(this);
@endif

        _ubxDriver.configure(ubxSettings);
        _ubxAssist = UBloxAssistNow(_ubxDriver);

        _assistDataStorage = SPIFlashFileSystem(HW_LD_SFFS_START_ADDR, HW_LD_SFFS_END_ADDR);
        _assistDataStorage.init();

        cm.onConnect(_onConnected.bindenv(this), "@{CLASS_NAME}");
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
            ::debug("Already getting location", "@{CLASS_NAME}");
            return _gettingLocation;
        }

        return _gettingLocation = _getLocationBLEBeacons()
        .fail(function(err) {
            ::info("Couldn't get location BLE beacons: " + err, "@{CLASS_NAME}");
            return _getLocationGNSS();
        }.bindenv(this))
        .fail(function(err) {
            ::info("Couldn't get location using GNSS: " + err, "@{CLASS_NAME}");
            return _getLocationCellTowersAndWiFi();
        }.bindenv(this))
        .then(function(location) {
            _gettingLocation = null;
            return location;
        }.bindenv(this), function(err) {
            ::info("Couldn't get location using WiFi networks and cell towers: " + err, "@{CLASS_NAME}");
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
            ::debug("Writing the UTC time to u-blox..", "@{CLASS_NAME}");
            _ubxAssist.writeUtcTimeAssist();
            return _writeAssistDataToUBlox();
        }.bindenv(this))
        .finally(function(_) {
            ::debug("Getting location using GNSS (u-blox)..", "@{CLASS_NAME}");
            return Promise(function(resolve, reject) {
                local onTimeout = function() {
                    // Failed to obtain the location
                    // Increase the fails counter, disable the u-blox, and reject the promise

                    // If the fails counter equals to LD_GNSS_FAILS_BEFORE_COOLDOWN, we activate the cooldown period.
                    // After this period, the counter will be reset and GNSS will be available again
                    if (++_gnssFailsCounter == LD_GNSS_FAILS_BEFORE_COOLDOWN) {
                        ::debug("GNSS cooldown period activated", "@{CLASS_NAME}");

                        local onCooldownPeriodFinish = function() {
                            ::debug("GNSS cooldown period finished", "@{CLASS_NAME}");
                            _gnssFailsCounter = 0;
                        }.bindenv(this);

                        imp.wakeup(LD_GNSS_COOLDOWN_PERIOD, onCooldownPeriodFinish);
                    }

                    _disableUBlox();
                    reject("Timeout");
                }.bindenv(this);

                local timeoutTimer = imp.wakeup(LD_GNSS_LOC_TIMEOUT, onTimeout);

                local onFix = function(location) {
                    ::info("Got location using GNSS", "@{CLASS_NAME}");
                    ::debug(location, "@{CLASS_NAME}");

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
        ::debug("Getting location using cell towers and WiFi..", "@{CLASS_NAME}");

        cm.keepConnection("@{CLASS_NAME}", true);

        local scannedWifis = null;
        local scannedTowers = null;
        local locType = null;

        // Run WiFi scanning in the background
        local scanWifiPromise = _esp.scanWiFiNetworks()
        .then(function(wifis) {
            scannedWifis = wifis;
        }.bindenv(this), function(err) {
            ::error("Couldn't scan WiFi networks: " + err, "@{CLASS_NAME}");
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

            ::debug("Sending results to the agent..", "@{CLASS_NAME}");

            return _requestToAgent(APP_RM_MSG_NAME.LOCATION_CELL_WIFI, locationData)
            .fail(function(err) {
                throw "Error sending a request to the agent: " + err;
            }.bindenv(this));
        }.bindenv(this))
        .then(function(resp) {
            cm.keepConnection("@{CLASS_NAME}", false);

            if (resp == null) {
                throw "No location received from the agent";
            }

            ::info("Got location using cell towers and/or WiFi", "@{CLASS_NAME}");
            ::debug(resp, "@{CLASS_NAME}");

            return {
                // Here we assume that if the device is connected, its time is synced
                "timestamp": time(),
                "type": locType,
                "accuracy": resp.accuracy,
                "longitude": resp.location.lng,
                "latitude": resp.location.lat
            };
        }.bindenv(this), function(err) {
            cm.keepConnection("@{CLASS_NAME}", false);
            throw err;
        }.bindenv(this));
    }
    
    /**
     * Obtain the current location using BLE beacons
     *
     * @return {Promise} that:
     * - resolves with the current location if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function _getLocationBLEBeacons() {
        ::debug("Getting location using BLE beacons..", "@{CLASS_NAME}");
        // Default accuracy
        const LD_BLE_BEACON_DEFAULT_ACCURACY = 10;

        local resBeacons = [];
        local resBeaconsRssi = [];
        local resBeaconsAddr = [];

        return _esp.scanBLEBeacons()
        .then(function(beacons) {
            // check known location beacons
            if (_beaconsWithKnownLocation != null) {
                foreach (discoveredBeacon in beacons) {
                    foreach (knownBeacon in _beaconsWithKnownLocation) {
                        if (discoveredBeacon.addr in knownBeacon) {
                            resBeacons.push(knownBeacon);
                            resBeaconsRssi.push(discoveredBeacon.rssi);
                            resBeaconsAddr.push(discoveredBeacon.addr);
                        }
                    }
                }
                local closestBeaconRssi = null;
                local closestBeaconInd = null;
                switch(resBeacons.len()) {
                    case 0:
                        return Promise.reject("No beacons available with known location");
                        break;
                    default:
                        foreach (ind, beaconRssi in resBeaconsRssi) {
                            if (closestBeaconRssi == null || beaconRssi > closestBeaconRssi) {
                                closestBeaconRssi = beaconRssi;
                                closestBeaconInd = ind;
                            }
                        }
                        return {
                            "timestamp": time(),
                            "type": "ble",
                            "accuracy": LD_BLE_BEACON_DEFAULT_ACCURACY,
                            "longitude": resBeacons[closestBeaconInd][resBeaconsAddr[closestBeaconInd]].lng,
                            "latitude": resBeacons[closestBeaconInd][resBeaconsAddr[closestBeaconInd]].lat
                        };
                        break;
                }
            } else {
                return Promise.reject("No beacons available with known location");
            }
        }.bindenv(this))
        .fail(function(err) {
            throw "Error scan BLE beacons: " + err;
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
            ::debug("Already getting u-blox assist data", "@{CLASS_NAME}");
            return _gettingAssistData;
        }

        local dataIsUpToDate = time() < _assistDataUpdateTs + LD_ASSIST_DATA_UPDATE_MIN_PERIOD;

        if (dataIsUpToDate || !cm.isConnected()) {
            dataIsUpToDate && ::debug("U-blox assist data is up to date...", "@{CLASS_NAME}");
            return Promise.resolve(null);
        }

        ::debug("Requesting u-blox assist data...", "@{CLASS_NAME}");

        return _gettingAssistData = _requestToAgent(APP_RM_MSG_NAME.GNSS_ASSIST)
        .then(function(data) {
            _gettingAssistData = null;

            if (data == null) {
                ::info("No u-blox assist data received", "@{CLASS_NAME}");
                return;
            }

            ::info("U-blox assist data received", "@{CLASS_NAME}");

            _assistDataUpdateTs = time();
            _eraseStaleUBloxAssistData();
            _saveUBloxAssistData(data);
        }.bindenv(this), function(err) {
            _gettingAssistData = null;
            ::info("U-blox assist data request failed: " + err, "@{CLASS_NAME}");
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

@if DEBUG_UBLOX
            ::debug("U-blox NAV_PVT msg received. Len: " + payload.len(), "@{CLASS_NAME}");
@endif

            if (parsed.error != null) {
                // TODO: Check if this can be printed and read ok
                ::error(parsed.error, "@{CLASS_NAME}");
                ::debug("The full payload containing the error: " + payload, "@{CLASS_NAME}");
                return;
            }

@if DEBUG_UBLOX
            // TODO: Log sometimes even when no DEBUG_UBLOX flag set? Just to indicate that the process is ongoing
            ::debug(format("Current u-blox info: fixType %d, satellites %d, accuracy %d",
                           parsed.fixType, parsed.numSV, _getUBloxAccuracy(parsed.hAcc)), "@{CLASS_NAME}");
@endif

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
        ::debug("Disable u-blox navigation messages...", "@{CLASS_NAME}._disableNavMsgs");
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
                    ::debug("Assist data has been written to u-blox successfully", "@{CLASS_NAME}");
                    return resolve(null);
                }

                ::error("Errors during u-blox assist data writing:", "@{CLASS_NAME}");
                foreach(err in errors) {
                    // Log errors encountered
                    ::error(err, "@{CLASS_NAME}");
                }

                reject(null);
            }.bindenv(this);

            ::debug("Writing assist data to u-blox..", "@{CLASS_NAME}");
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

        ::debug("Reading u-blox assist data..", "@{CLASS_NAME}");

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
                ::debug("No applicable u-blox assist data found", "@{CLASS_NAME}");
                return null;
            }

            ::debug("Found applicable u-blox assist data with the following date: " + chosenFile, "@{CLASS_NAME}");

            local file = _assistDataStorage.open(chosenFile, "r");
            local data = file.read();
            file.close();
            data.seek(0, 'b');

            return data;
        } catch (err) {
            ::error("Couldn't read u-blox assist data: " + err, "@{CLASS_NAME}");
        }

        return null;
    }

    /**
     * Save u-blox assist data to the storage
     *
     * @param {blob} data - Assist data
     */
    function _saveUBloxAssistData(data) {
        ::debug("Saving u-blox assist data..", "@{CLASS_NAME}");

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
            ::error("Couldn't save u-blox assist data: " + err, "@{CLASS_NAME}");
        }
    }

    /**
     * Erase stale u-blox assist data from the storage
     */
    function _eraseStaleUBloxAssistData() {
        ::debug("Erasing stale u-blox assist data..", "@{CLASS_NAME}");

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
                    ::error("Couldn't check the date of a u-blox assist data file: " + err, "@{CLASS_NAME}");
                }

                if (erase) {
                    ::debug("Erasing u-blox assist data file: " + name, "@{CLASS_NAME}");
                    // Erase stale assist message
                    _assistDataStorage.eraseFile(name);
                }
            }
        } catch (err) {
            ::error("Couldn't erase stale u-blox assist data: " + err, "@{CLASS_NAME}");
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

@if DEBUG_UBLOX
    function _onUBloxMessage(msg, classId = null) {
        if (classId != null) {
            // Received UBX message
            _onUBloxUbxMsg(msg, classId);
         } else {
            // Received NMEA sentence
            _onUBloxNmeaMsg(msg);
         }
    }

    function _onUBloxUbxMsg(payload, classId) {
        ::debug("U-blox UBX msg received:", "@{CLASS_NAME}");

        // Log message info
        ::debug(format("Msg Class ID: 0x%04X", classId), "@{CLASS_NAME}");
        ::debug("Msg len: " + payload.len(), "@{CLASS_NAME}");
    }

    function _onUBloxNmeaMsg(sentence) {
        ::debug("U-blox NMEA msg received:", "@{CLASS_NAME}");

        // Log NMEA message
        ::debug(sentence, "@{CLASS_NAME}");
    }

    function _onUBloxACK(payload) {
        ::debug("U-blox ACK_ACK msg received", "@{CLASS_NAME}");

        local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.ACK_ACK](payload);
        if (parsed.error != null) {
            ::error(parsed.error, "@{CLASS_NAME}");
        } else {
            ::debug(format("ACK-ed msgId: 0x%04X", parsed.ackMsgClassId), "@{CLASS_NAME}");
        }
    }

    function _onUBloxNAK(payload) {
        ::debug("U-blox ACK_NAK msg received", "@{CLASS_NAME}");

        local parsed = UbxMsgParser[UBX_MSG_PARSER_CLASS_MSG_ID.ACK_NAK](payload);
        if (parsed.error != null) {
            ::error(parsed.error, "@{CLASS_NAME}");
        } else {
            ::error(format("NAK-ed msgId: 0x%04X", parsed.nakMsgClassId), "@{CLASS_NAME}");
        }
    }
@endif

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
            ::error("Invalid date object passed: " + err, "@{CLASS_NAME}");
            return 0;
        }
    }
}

@set CLASS_NAME = null // Reset the variable
