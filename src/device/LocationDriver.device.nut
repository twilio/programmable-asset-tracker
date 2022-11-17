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

@set CLASS_NAME = "LocationDriver" // Class name for logging

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

        cm.onConnect(_onConnected.bindenv(this), "@{CLASS_NAME}");
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
            ::debug("Already getting location", "@{CLASS_NAME}");
            return _gettingLocation;
        }

        return _gettingLocation = _getLocationBLEDevices()
        .fail(function(err) {
            if (err == null) {
                ::debug("Location using BLE devices is disabled", "@{CLASS_NAME}");
            } else {
                ::info("Couldn't get location using BLE devices: " + err, "@{CLASS_NAME}");
            }

            return _getLocationGNSS();
        }.bindenv(this))
        .fail(function(err) {
            ::info("Couldn't get location using GNSS: " + err, "@{CLASS_NAME}");
            return _getLocationCellTowersAndWiFi();
        }.bindenv(this))
        .then(function(location) {
            _gettingLocation = null;
            // Save this location as the last known one
            _save(location, LD_FILE_NAMES.LAST_KNOWN_LOCATION, Serializer.serialize.bindenv(Serializer));
            return location;
        }.bindenv(this), function(err) {
            ::info("Couldn't get location using WiFi networks and cell towers: " + err, "@{CLASS_NAME}");
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
        ::debug("Switched ON the u-blox module", "@{CLASS_NAME}");

        return _updateAssistData()
        .finally(function(_) {
            ::debug("Writing the UTC time to u-blox..", "@{CLASS_NAME}");
            local ubxAssist = UBloxAssistNow(ubxDriver);
            ubxAssist.writeUtcTimeAssist();
            return _writeAssistDataToUBlox(ubxAssist);
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
        ::debug("Getting location using cell towers and WiFi..", "@{CLASS_NAME}");

        cm.keepConnection("@{CLASS_NAME}", true);

        local scannedWifis = null;
        local scannedTowers = null;
        local locType = null;

        // Run WiFi scanning in the background
        local scanWifiPromise = _esp.scanWiFiNetworks()
        .then(function(wifis) {
            scannedWifis = wifis.len() > 0 ? wifis : null;
        }.bindenv(this), function(err) {
            ::error("Couldn't scan WiFi networks: " + err, "@{CLASS_NAME}");
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

        ::debug("Getting location using BLE devices..", "@{CLASS_NAME}");

        local knownGeneric = _knownBLEDevices.generic;
        local knownIBeacons = _knownBLEDevices.iBeacon;

        return _esp.scanBLEAdverts()
        .then(function(adverts) {
            // Table of "recognized" advertisements (for which the location is known) and their locations
            local recognized = {};

            foreach (advert in adverts) {
                if (advert.address in knownGeneric) {
                    ::debug("A generic BLE device with known location found: " + advert.address, "@{CLASS_NAME}");

                    recognized[advert] <- knownGeneric[advert.address];
                    continue;
                }

                local parsed = _parseIBeaconPacket(advert.advData);

                if (parsed && parsed.uuid  in knownIBeacons
                           && parsed.major in knownIBeacons[parsed.uuid]
                           && parsed.minor in knownIBeacons[parsed.uuid][parsed.major]) {
                    local iBeaconInfo = format("UUID %s, Major %s, Minor %s", parsed.uuid, parsed.major, parsed.minor);
                    ::debug(format("An iBeacon device with known location found: %s, %s", advert.address, iBeaconInfo), "@{CLASS_NAME}");

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

            ::info("Got location using BLE devices", "@{CLASS_NAME}");
            ::debug("The closest BLE device with known location: " + closestDevice.address, "@{CLASS_NAME}");
            ::debug(recognized[closestDevice], "@{CLASS_NAME}");

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

@if DEBUG_UBLOX
        // Register handlers with debug logging only if needed
        // Register command ACK and NAK callbacks
        ubxDriver.registerOnMessageCallback(UBX_MSG_PARSER_CLASS_MSG_ID.ACK_ACK, _onUBloxACK.bindenv(this));
        ubxDriver.registerOnMessageCallback(UBX_MSG_PARSER_CLASS_MSG_ID.ACK_NAK, _onUBloxNAK.bindenv(this));
        // Register general handler
        ubxSettings.defaultOnMsg <- _onUBloxMessage.bindenv(this);
@endif

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

@if DEBUG_UBLOX
            ::debug("U-blox NAV_PVT msg received. Len: " + payload.len(), "@{CLASS_NAME}");
@endif

            if (parsed.error != null) {
                // NOTE: This may be printed as binary data
                ::error(parsed.error, "@{CLASS_NAME}");
                ::debug("The full payload containing the error: " + payload, "@{CLASS_NAME}");
                return;
            }


@if DEBUG_UBLOX
            ::debug(format("Current u-blox info: fixType %d, satellites %d, accuracy %d",
                           parsed.fixType, parsed.numSV, _getUBloxAccuracy(parsed.hAcc)), "@{CLASS_NAME}");
@else
            if (!("satellitesUsed" in _extraInfo.gnss) || _extraInfo.gnss.satellitesUsed != parsed.numSV) {
                ::debug(format("Current u-blox info: fixType %d, satellites %d, accuracy %d",
                        parsed.fixType, parsed.numSV, _getUBloxAccuracy(parsed.hAcc)), "@{CLASS_NAME}");
            }
@endif

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
        ::debug("Switched OFF the u-blox module", "@{CLASS_NAME}");
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
                    ::debug("Assist data has been written to u-blox successfully", "@{CLASS_NAME}");
                    return resolve(null);
                }

                ::info(format("Assist data has been written to u-blox successfully except %d assist messages", errors.len()), "@{CLASS_NAME}");
                foreach(err in errors) {
                    // Log errors encountered
                    ::debug(err, "@{CLASS_NAME}");
                }

                reject(null);
            }.bindenv(this);

            ::debug("Writing assist data to u-blox..", "@{CLASS_NAME}");
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

        ::debug("Reading u-blox assist data..", "@{CLASS_NAME}");

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
                ::debug("No applicable u-blox assist data found", "@{CLASS_NAME}");
                return null;
            }

            ::debug("Found applicable u-blox assist data with the following date: " + chosenFile, "@{CLASS_NAME}");

            local data = _load(chosenFile);
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

        ::debug("Erasing stale u-blox assist data..", "@{CLASS_NAME}");

        try {
            local files = _storage.getFileList();
            // Since the date has the following format YYYYMMDD, we can compare dates as integer numbers
            local yesterday = UBloxAssistNow.getDateString(date(time() - LD_DAY_SEC)).tointeger();

            ::debug("There are " + files.len() + " file(s) in the storage", "@{CLASS_NAME}");

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
                    ::debug("Erasing u-blox assist data file: " + name, "@{CLASS_NAME}");
                    // Erase stale assist message
                    _storage.eraseFile(name);
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

    // -------------------- STORAGE METHODS -------------------- //

    function _save(data, fileName, encoder = null) {
        _erase(fileName);

        try {
            local file = _storage.open(fileName, "w");
            file.write(encoder ? encoder(data) : data);
            file.close();
        } catch (err) {
            ::error(format("Couldn't save data (file name = %s): %s", fileName, err), "@{CLASS_NAME}");
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
            ::error(format("Couldn't load data (file name = %s): %s", fileName, err), "@{CLASS_NAME}");
        }

        return null;
    }

    function _erase(fileName) {
        try {
            // Erase the existing file if any
            _storage.fileExists(fileName) && _storage.eraseFile(fileName);
        } catch (err) {
            ::error(format("Couldn't erase data (file name = %s): %s", fileName, err), "@{CLASS_NAME}");
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
            ::error("Invalid date object passed: " + err, "@{CLASS_NAME}");
            return 0;
        }
    }
}

@set CLASS_NAME = null // Reset the variable
