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

    // Array of alert names
    _alertNames = null;

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
        _allAlerts = {"shockDetected"       : false,
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
     *                                      Default: DEFAULT_SHOCK_THRESHOLD
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
            ::info("Accelerometer driver object is null", "@{CLASS_NAME}");
        }

        if (_mm) {
            _mm.setNewLocationCb(_onNewLocation.bindenv(this));
            _mm.setMotionEventCb(_onMotionEvent.bindenv(this));
            _mm.setGeofencingEventCb(_onGeofencingEvent.bindenv(this));
        } else {
            ::info("Motion monitor object is null", "@{CLASS_NAME}");
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
            ::error("Incorrect type of settings parameter", "@{CLASS_NAME}");
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
                        ::error("Incorrect key name", "@{CLASS_NAME}");
                        break;
                }
            } else {
                ::error("Incorrect key type", "@{CLASS_NAME}");
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
     *  Data sending function.
     */
    function _dataSend() {
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

    function _checkTemperature() {
        // get the current temperature, check alert conditions
        local res = _ts.read();
        if ("error" in res) {
            ::error("Failed to read temperature: " + res.error, "@{CLASS_NAME}");
            _curTemper = DP_INIT_TEMPER_VALUE;
        } else {
            _curTemper = res.temperature;
            ::debug("Temperature: " + _curTemper);
        }
        
        if (_curTemper > _temperatureHighAlertThr) {
            if (_temperatureState != DP_TEMPERATURE_LEVEL.T_HIGHER_RANGE) {
                _allAlerts.temperatureHigh = true;
                _temperatureState = DP_TEMPERATURE_LEVEL.T_HIGHER_RANGE;
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
            }
        }

        if ((_temperatureState == DP_TEMPERATURE_LEVEL.T_BELOW_RANGE) &&
            (_curTemper > (_temperatureLowAlertThr + DP_TEMPER_HYST)) &&
            (_curTemper < _temperatureHighAlertThr)) {
            _temperatureState = DP_TEMPERATURE_LEVEL.T_IN_RANGE;
        }
    }

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
     *  Data and alerts reading and processing.
     */
    function _dataProc() {

        _dataReadingTimer && imp.cancelwakeup(_dataReadingTimer);

        // check temperature
        _checkTemperature();
        // check battery level
        _checkBatteryVoltLevel();

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
                       "sensors":{"batteryLevel": _curBatteryLev,
                                   "temperature": _curTemper == DP_INIT_TEMPER_VALUE ? 0 : _curTemper}, // send 0 degrees of Celsius if termosensor error
                       "alerts":alerts};

        ::info("Message:", "@{CLASS_NAME}");
        ::info("trackerId: " + _dataMesg.trackerId + ", timestamp: " + _dataMesg.timestamp +
               ", inMotion: " + _inMotion +
               ", location timestamp: " + _currentLocation.timestamp + ", type: " +
               _currentLocation.type + ", accuracy: " + _currentLocation.accuracy +
               ", lng: " + _currentLocation.longitude + ", lat: " + _currentLocation.latitude +
               ", batteryLevel: " + _curBatteryLev + ", temperature: " +
               _curTemper, "@{CLASS_NAME}");
        ::info("Alerts:", "@{CLASS_NAME}");
        if (alertsCount > 0) {
            foreach (item in alerts) {
                ::info(item, "@{CLASS_NAME}");
            }
        }

        rm.send(APP_RM_MSG_NAME.DATA, clone _dataMesg, RM_IMPORTANCE_HIGH);

        // If current alerts count more then 0
        if (alertsCount > 0) {
            _dataSend();
        }

        _dataReadingTimer = imp.wakeup(_dataReadingPeriod,
                                       _dataProcTimerCb.bindenv(this));
    }

    /**
     *  The handler is called when a new location is received.
     *  @param {bool} isFresh - false if the latest location has not been determined, the provided data is the previous location
     *  @param {table} loc - Location information.
     *      The fields:
     *          "timestamp": {integer}  - Time value
     *               "type": {string}   - gnss or cell e.g.
     *           "accuracy": {integer}  - Accuracy in meters
     *          "longitude": {float}    - Longitude in degrees
     *           "latitude": {float}    - Latitude in degrees
     */
    function _onNewLocation(isFresh, loc) {
        if (loc && typeof loc == "table" && typeof isFresh == "bool") {
            _currentLocation = loc;
        } else {
            ::error("Error type of location value", "@{CLASS_NAME}");
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
    }

    /**
     *  The handler is called when a motion event is detected.
     *  @param {bool} eventType - true: motion started, false: motion stopped
     */
    function _onMotionEvent(eventType) {
        if (eventType) {
            _allAlerts.motionStarted = true;
            _inMotion = true;
        } else {
            _allAlerts.motionStopped = true;
            _inMotion = false;
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
