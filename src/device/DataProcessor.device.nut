@set CLASS_NAME = "DataProcessor" // Class name for logging

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
            // TODO: Do we need alerts like trackerReset, trackerReconfigured?
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
     *  Start data processing.
     *  @param {table} cfg - Table with the full configuration.
     *                       For details, please, see the documentation
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function start(cfg) {
        cm.onConnect(_getCellInfo.bindenv(this), "@{CLASS_NAME}");

        updateCfg(cfg);

        _lm.setGeofencingEventCb(_onGeofencingEvent.bindenv(this));
        _lm.setRepossessionEventCb(_onRepossessionEvent.bindenv(this));
        _mm.setMotionEventCb(_onMotionEvent.bindenv(this));

        return Promise.resolve(null);
    }

    // TODO: Comment
    function updateCfg(cfg) {
        _updCfgAlerts(cfg);
        // This call will trigger data reading/sending. So it should be the last one
        _updCfgGeneral(cfg);

        return Promise.resolve(null);
    }

    // -------------------- PRIVATE METHODS -------------------- //

    // TODO: Comment
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

    // TODO: Comment
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

    // TODO: Comment
    function _configureShockDetection() {
        if (_alertsSettings.shockDetected.enabled) {
            ::debug("Activating shock detection..", "@{CLASS_NAME}");
            local settings = { "shockThreshold" : _alertsSettings.shockDetected.threshold };
            _ad.enableShockDetection(_onShockDetectedEvent.bindenv(this), settings);
        } else {
            _ad.enableShockDetection(null);
        }
    }

    // TODO: Comment
    function _configureTamperingDetection() {
        if (_alertsSettings.tamperingDetected.enabled) {
            ::debug("Activating tampering detection..", "@{CLASS_NAME}");
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

            ::debug("Message: " + JSONEncoder.encode(dataMsg), "@{CLASS_NAME}");

            // ReplayMessenger saves the message till imp-device is connected
            rm.send(APP_RM_MSG_NAME.DATA, dataMsg, RM_IMPORTANCE_HIGH);
            ledIndication && ledIndication.indicate(LI_EVENT_TYPE.NEW_MSG);

            if (alerts.len() > 0) {
                ::info("Alerts:", "@{CLASS_NAME}");
                foreach (item in alerts) {
                    ::info(item, "@{CLASS_NAME}");
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
            ::error("Failed to read temperature: " + err, "@{CLASS_NAME}");
            // Don't generate alerts and don't send temperature to the cloud
            _temperature = null;
            return;
        }

        ::debug("Temperature: " + _temperature, "@{CLASS_NAME}");

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
     */
    function _checkBatteryLevel() {
        return _bd.measureBattery()
        .then(function(level) {
            _batteryLevel = level.percent;

            ::debug("Battery level: " + _batteryLevel + "%", "@{CLASS_NAME}");

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
            ::error("Failed to get battery level: " + err, "@{CLASS_NAME}");
            // Don't generate alerts and don't send battery level to the cloud
            _batteryLevel = null;
        }.bindenv(this));
    }

    // TODO: Comment
    function _getCellInfo() {
        if (!cm.isConnected()) {
            return Promise.resolve(null);
        }

        return Promise(function(resolve, reject) {
            // TODO: This is a temporary defense from the incorrect work of getcellinfo()
            local cbTimeoutTimer = imp.wakeup(5, function() {
                reject("imp.net.getcellinfo didn't call its callback!");
            }.bindenv(this));

            // TODO: Can potentially be called in parallel - need to avoid this
            imp.net.getcellinfo(function(cellInfo) {
                imp.cancelwakeup(cbTimeoutTimer);
                _lastCellInfo = _extractCellInfoBG95(cellInfo);
                resolve(null);
            }.bindenv(this));
        }.bindenv(this))
        .fail(function(err) {
            ::error("Failed getting cell info: " + err, "@{CLASS_NAME}");
        }.bindenv(this));
    }

    // TODO: Comment
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
            ::error(format("Couldn't parse cell info: '%s'. Raw cell info:\n%s", err, cellInfo), "@{CLASS_NAME}", true);
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

@set CLASS_NAME = null // Reset the variable
