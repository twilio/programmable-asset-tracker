@set CLASS_NAME = "LocationDriver" // Class name for logging

// GNSS options:
// Accuracy threshold of positioning, in meters. Range: 1-1000.
const LD_GNSS_ACCURACY = 10;
// The maximum positioning time, in seconds. Range: 1-255
const LD_LOC_TIMEOUT = 55;

// Minimum time of BG96 assist data validity to skip updating of the assist data, in minutes
const LD_ASSIST_DATA_MIN_VALID_TIME = 1440;

// Location Driver class.
// Determines the current position.
class LocationDriver {
    // Assist data validity time, in minutes
    _assistDataValidityTime = 0;
    // Promise that resolves or rejects when the assist data has been obtained.
    // null if the assist data is not being obtained at the moment
    _gettingAssistData = null;
    // Ready-to-use assist data
    _assistData = null;
    // ESP32 object
    _esp = null;

    /**
     * Constructor for Location Driver
     */
    constructor() {
        cm.onConnect(_onConnected.bindenv(this), "@{CLASS_NAME}");
        _esp = ESP32Driver(HW_ESP_POWER_EN_PIN, HW_ESP_UART);
        // Set a "finally" handler only to avoid "Unhandled promise rejection" message
        _updateAssistData()
        .finally(@(_) null);
    }

    /**
     * Obtain and return the current location.
     * - First, try to get GNSS fix
     * - If no success, try to obtain location using cell towers info
     *
     * @return {Promise} that:
     * - resolves with the current location if the operation succeeded
     * - rejects if the operation failed
     */
    function getLocation() {
        return _getLocationGNSS()
        .fail(function(err) {
            ::info("Couldn't get location using GNSS: " + err, "@{CLASS_NAME}");
            return _getLocationCellTowers();
        }.bindenv(this))
        .fail(function(err) {
            ::info("Couldn't get location using cell towers: " + err, "@{CLASS_NAME}");
            return Promise.reject(null);
        }.bindenv(this));
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Obtain the current location using GNSS.
     *
     * @return {Promise} that:
     * - resolves with the current location if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function _getLocationGNSS() {
        return _updateAssistData()
        .finally(function(_) {
            ::debug("Getting location using GNSS..", "@{CLASS_NAME}");
            return Promise(function(resolve, reject) {
                BG96_GPS.enableGNSS({
                    "onLocation": _onGnssLocationFunc(resolve, reject),
                    "onEnabled": _onGnssEnabledFunc(reject),
                    "maxPosTime": LD_LOC_TIMEOUT,
                    "accuracy": LD_GNSS_ACCURACY,
                    "useAssist": true,
                    "assistData": _assistData
                });

                // We've just applied pending assist data (if any), so we clear it
                _assistData = null;
            }.bindenv(this));
        }.bindenv(this));
    }

    /**
     * Obtain the current location using cell towers info.
     *
     * @return {Promise} that:
     * - resolves with the current location if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function _getLocationCellTowers() {
        ::debug("Getting location using cell towers...", "@{CLASS_NAME}");

        cm.keepConnection("@{CLASS_NAME}", true);

        return cm.connect()
        .fail(function(_) {
            throw "Couldn't connect to the server";
        }.bindenv(this))
        .then(function(_) {
            local scannedTowers = BG96CellInfo.scanCellTowers();

            if (scannedTowers == null) {
                throw "No towers scanned";
            }

            ::debug("Cell towers scanned. Sending results to the agent..", "@{CLASS_NAME}");

            return _requestToAgent(APP_RM_MSG_NAME.LOCATION_CELL, scannedTowers)
            .fail(function(err) {
                throw "Error sending a request to the agent: " + err;
            }.bindenv(this));
        }.bindenv(this))
        .then(function(location) {
            cm.keepConnection("@{CLASS_NAME}", false);

            if (location == null) {
                throw "No location received from the agent";
            }

            ::info("Got location using cell towers", "@{CLASS_NAME}");
            ::debug(location, "@{CLASS_NAME}");

            return {
                // Here we assume that if the device is connected, its time is synced
                "timestamp": time(),
                "type": "cell",
                "accuracy": location.accuracy,
                "longitude": location.lon,
                "latitude": location.lat
            };
        }.bindenv(this), function(err) {
            cm.keepConnection("@{CLASS_NAME}", false);
            throw err;
        }.bindenv(this));
    }

    /**
     * Obtain the current location using WiFi networks info.
     *
     * @return {Promise} that:
     * - resolves with the current location if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function _getLocationWiFi() {
        ::debug("Getting location using WiFi networks..", "@{CLASS_NAME}");

        return _esp.init()
        .fail(function(_) {
            throw "Couldn't init ESP32";
        }.bindenv(this))
        .then(function(_) {

            ::debug("Scan WiFi networks. Sending results to the agent..", "@{CLASS_NAME}");

            return _esp.scanWiFiNetworks()
            .fail(function(err) {
                throw "Scan WiFi network error: " + error;
            }.bindenv(this));
        }.bindenv(this))
        .then(function(wifiNetworks) {
            return _requestToAgent(APP_RM_MSG_NAME.LOCATION_WIFI, wifiNetworks)
            .fail(function(err) {
                throw "Error sending a request to the agent: " + err;
            }.bindenv(this));
        }.bindenv(this))
        .then(function(location) {

            if (location == null) {
                throw "No location received from the agent";
            }

            ::info("Got location using WiFi networks", "@{CLASS_NAME}");
            ::debug(location, "@{CLASS_NAME}");

            return {
                // Here we assume that if the device is connected, its time is synced
                "timestamp": time(),
                "type": "wifi",
                "accuracy": location.accuracy,
                "longitude": location.lon,
                "latitude": location.lat
            };
        }.bindenv(this), function(err) {
            throw err;
        }.bindenv(this));
    }

    /**
     * Create a handler called when GNSS is enabled or an error occurred
     *
     * @param {function} onError - Function to be called in case of an error during enabling of GNSS
     *         onError(error), where
     *         @param {string} error - Error occurred during enabling of GNSS
     *
     * @return {function} Handler called when GNSS is enabled or an error occurred
     */
    function _onGnssEnabledFunc(onError) {
        return function(err) {
            if (err == null) {
                ::debug("GNSS enabled successfully", "@{CLASS_NAME}");

                // Update the validity info
                local assistDataValidity = BG96_GPS.isAssistDataValid();
                if (assistDataValidity.valid) {
                    _assistDataValidityTime = assistDataValidity.time;
                } else {
                    _assistDataValidityTime = 0;
                }

                ::debug("Assist data validity time (min): " + _assistDataValidityTime, "@{CLASS_NAME}");
            } else {
                onError("Error enabling GNSS: " + err);
            }
        }.bindenv(this);
    }

    /**
     * Create a handler called when GNSS location data is ready or an error occurred
     *
     * @param {function} onFix - Function to be called in case of successful getting of a GNSS fix
     *         onFix(fix), where
     *         @param {table} fix - GNSS fix (location) data
     * @param {function} onError - Function to be called in case of an error during GNSS locating
     *         onError(error), where
     *         @param {string} error - Error occurred during GNSS locating
     *
     * @return {function} Handler called when GNSS is enabled or an error occurred
     */
    function _onGnssLocationFunc(onFix, onError) {
        // A valid timestamp will surely be greater than this value (01.01.2021)
        const LD_VALID_TS = 1609459200;

        return function(result) {
            BG96_GPS.disableGNSS();

            if (!("fix" in result)) {
                if ("error" in result) {
                    onError(result.error);
                } else {
                    onError("Unknown error");
                }

                return;
            }

            ::info("Got location using GNSS", "@{CLASS_NAME}");
            ::debug(result.fix, "@{CLASS_NAME}");

            local accuracy = ((4.0 * result.fix.hdop.tofloat()) + 0.5).tointeger();

            onFix({
                // If we don't have the valid time, we take it from the location data
                "timestamp": time() > LD_VALID_TS ? time() : result.fix.time,
                "type": "gnss",
                "accuracy": accuracy,
                "longitude": result.fix.lon.tofloat(),
                "latitude": result.fix.lat.tofloat()
            });
        }.bindenv(this);
    }

    /**
     * Handler called every time imp-device becomes connected
     */
    function _onConnected() {
        // Set a "finally" handler only to avoid "Unhandled promise rejection" message
        _updateAssistData()
        .finally(@(_) null);
    }

    /**
     * Update GNSS Assist data if needed
     *
     * @return {Promise} that:
     * - resolves if assist data was obtained
     * - rejects if there is no need to update assist data or an error occurred
     */
    function _updateAssistData() {
        if (_gettingAssistData) {
            ::debug("Already getting assist data", "@{CLASS_NAME}");
            return _gettingAssistData;
        }

        if (_assistData || _assistDataValidityTime >= LD_ASSIST_DATA_MIN_VALID_TIME || !cm.isConnected()) {
            // If we already have ready-to-use assist data or assist data validity time is big enough,
            // it doesn't matter if we resolve or reject the promise.
            // Since the update was actually not done, let's just reject it
            return Promise.reject(null);
        }

        ::debug("Requesting assist data...", "@{CLASS_NAME}");

        return _gettingAssistData = _requestToAgent(APP_RM_MSG_NAME.GNSS_ASSIST)
        .then(function(data) {
            _gettingAssistData = null;

            if (data == null) {
                ::info("No GNSS Assist data received", "@{CLASS_NAME}");
                return Promise.reject(null);
            }

            ::info("GNSS Assist data received", "@{CLASS_NAME}");
            _assistData = data;
        }.bindenv(this), function(err) {
            _gettingAssistData = null;
            ::info("GNSS Assist data request failed: " + err, "@{CLASS_NAME}");
            return Promise.reject(null);
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
}

@set CLASS_NAME = null // Reset the variable
