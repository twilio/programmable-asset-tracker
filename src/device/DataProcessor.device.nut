@set CLASS_NAME = "DataProcessor" // Class name for logging

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
    _curTemper = DP_INIT_TEMPER_VALUE;

    // Last battery level
    _curBatteryLev = DP_INIT_BATTERY_LEVEL;

    // Array of alerts
    _allAlerts = null;

    // state battery (voltage in permissible range or not)
    _batteryState = DP_BATTERY_VOLT_LEVEL.V_IN_RANGE;

    // temperature state (temperature in permissible range or not)
    _temperatureState = DP_TEMPERATURE_LEVEL.T_IN_RANGE;

    // Settings of shock, temperature and battery alerts
    _alertsSettings = null;

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

        _allAlerts = {
            // TODO: Do we need alerts like trackerReset, trackerReconfigured?
            "shockDetected"   : false,
            "motionStarted"   : false,
            "motionStopped"   : false,
            "geofenceEntered" : false,
            "geofenceExited"  : false,
            "temperatureHigh" : false,
            "temperatureLow"  : false,
            "batteryLow"      : false
        };

        _alertsSettings = {
            "shockDetected"   : {},
            "temperatureHigh" : {},
            "temperatureLow"  : {},
            "batteryLow"      : {}
        };
    }

    /**
     *  Start data processing.
     *  @param {table} cfg - Table with the full configuration.
     *                       For details, please, see the documentation
     */
    function start(cfg) {
        updateCfg(cfg);

        _mm.setMotionEventCb(_onMotionEvent.bindenv(this));
        _mm.setGeofencingEventCb(_onGeofencingEvent.bindenv(this));

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
        local alertsCfg = getValFromTable(cfg, "alerts");
        local shockDetectedCfg   = getValFromTable(alertsCfg, "shockDetected");
        local temperatureHighCfg = getValFromTable(alertsCfg, "temperatureHigh");
        local temperatureLowCfg  = getValFromTable(alertsCfg, "temperatureLow");
        local batteryLowCfg      = getValFromTable(alertsCfg, "batteryLow");

        if (shockDetectedCfg) {
            _allAlerts.shockDetected = false;
            mixTables(shockDetectedCfg, _alertsSettings.shockDetected);
            _configureShockDetection();
        }
        if (temperatureHighCfg || temperatureLowCfg) {
            _temperatureState = DP_TEMPERATURE_LEVEL.T_IN_RANGE;
            _allAlerts.temperatureHigh = false;
            _allAlerts.temperatureLow = false;
            mixTables(temperatureHighCfg, _alertsSettings.temperatureHigh);
            mixTables(temperatureLowCfg, _alertsSettings.temperatureLow);
        }
        if (batteryLowCfg) {
            _batteryState = DP_BATTERY_VOLT_LEVEL.V_IN_RANGE;
            _allAlerts.batteryLow = false;
            mixTables(batteryLowCfg, _alertsSettings.batteryLow);
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
        // read temperature, check alert conditions
        _checkTemperature();

        // read battery level, check alert conditions
        _checkBatteryVoltLevel();

        // check if alerts have been triggered
        local alerts = [];
        foreach (key, val in _allAlerts) {
            if (val) {
                alerts.append(key);
                _allAlerts[key] = false;
            }
        }
        local alertsCount = alerts.len();

        local status = _mm.getStatus();

        _dataMesg = {
            "trackerId": hardware.getdeviceid(),
            "timestamp": time(),
            "status": status.flags,
            "location": {
                "timestamp": status.location.timestamp,
                "type": status.location.type,
                "accuracy": status.location.accuracy,
                "lng": status.location.longitude,
                "lat": status.location.latitude
            },
            "sensors": {},
            "alerts": alerts
        };
        if (_curTemper != DP_INIT_TEMPER_VALUE) {
            _dataMesg.sensors.temperature <- _curTemper;
        }
        ::debug("Message: " + JSONEncoder.encode(_dataMesg), "@{CLASS_NAME}");

        if (alertsCount > 0) {
            ::info("Alerts:", "@{CLASS_NAME}");
            foreach (item in alerts) {
                ::info(item, "@{CLASS_NAME}");
            }
        }

        // ReplayMessenger saves the message till imp-device is connected
        rm.send(APP_RM_MSG_NAME.DATA, clone _dataMesg, RM_IMPORTANCE_HIGH);
        ledIndication && ledIndication.indicate(LI_EVENT_TYPE.NEW_MSG);

        // If at least one alert, try to send data immediately
        if (alertsCount > 0) {
            _dataSend();
        }

        _dataReadingTimer && imp.cancelwakeup(_dataReadingTimer);
        _dataReadingTimer = imp.wakeup(_dataReadingPeriod,
                                       _dataProcTimerCb.bindenv(this));
    }

    /**
     *  Read temperature, check alert conditions
     */
    function _checkTemperature() {
        local res = _ts.read();
        if ("error" in res) {
            ::error("Failed to read temperature: " + res.error, "@{CLASS_NAME}");
            // Don't generate a temperatureLow alert and don't send temperature to the cloud
            _curTemper = DP_INIT_TEMPER_VALUE;
            return;
        } else {
            _curTemper = res.temperature;
            ::debug("Temperature: " + _curTemper, "@{CLASS_NAME}");
        }

        local tempHigh = _alertsSettings.temperatureHigh;
        local tempLow = _alertsSettings.temperatureLow;

        if (tempHigh.enabled) {
            if (_curTemper > tempHigh.threshold) {
                if (_temperatureState != DP_TEMPERATURE_LEVEL.T_HIGHER_RANGE) {
                    _allAlerts.temperatureHigh = true;
                    _temperatureState = DP_TEMPERATURE_LEVEL.T_HIGHER_RANGE;

                    ledIndication && ledIndication.indicate(LI_EVENT_TYPE.ALERT_TEMP_HIGH);
                }
            }

            if ((_temperatureState == DP_TEMPERATURE_LEVEL.T_HIGHER_RANGE) &&
                (_curTemper < (tempHigh.threshold - tempHigh.hysteresis)) &&
                (!tempLow.enabled || _curTemper > tempLow.threshold)) {
                _temperatureState = DP_TEMPERATURE_LEVEL.T_IN_RANGE;
            }
        }

        if (tempLow.enabled) {
            if (_curTemper < tempLow.threshold &&
                _curTemper != DP_INIT_TEMPER_VALUE) {
                if (_temperatureState != DP_TEMPERATURE_LEVEL.T_BELOW_RANGE) {
                    _allAlerts.temperatureLow = true;
                    _temperatureState = DP_TEMPERATURE_LEVEL.T_BELOW_RANGE;

                    ledIndication && ledIndication.indicate(LI_EVENT_TYPE.ALERT_TEMP_LOW);
                }
            }

            if ((_temperatureState == DP_TEMPERATURE_LEVEL.T_BELOW_RANGE) &&
                (_curTemper > (tempLow.threshold + tempLow.hysteresis)) &&
                (!tempHigh.enabled || _curTemper < tempHigh.threshold)) {
                _temperatureState = DP_TEMPERATURE_LEVEL.T_IN_RANGE;
            }
        }
    }

    /**
     *  Read battery level, check alert conditions
     */
    function _checkBatteryVoltLevel() {
        if (!_alertsSettings.batteryLow.enabled) {
            return;
        }

        local batteryLowThr = _alertsSettings.batteryLow.threshold;

        // get the current battery level, check alert conditions - TODO
        if (_curBatteryLev < batteryLowThr &&
            _curBatteryLev != DP_INIT_BATTERY_LEVEL) {
                if (_batteryState == DP_BATTERY_VOLT_LEVEL.V_IN_RANGE) {
                    _allAlerts.batteryLow = true;
                    _batteryState = DP_BATTERY_VOLT_LEVEL.V_NOT_IN_RANGE;
                }
        }

        if (_curBatteryLev > (batteryLowThr + DP_BATTERY_LEV_HYST)) {
            _batteryState = DP_BATTERY_VOLT_LEVEL.V_IN_RANGE;
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
            ::error("Error type of battery level", "@{CLASS_NAME}");
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
}

@set CLASS_NAME = null // Reset the variable
