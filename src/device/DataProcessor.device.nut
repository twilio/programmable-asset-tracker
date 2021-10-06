@set CLASS_NAME = "DataProcessor" // Class name for logging

// Alert bit numbers in alert state variable
enum ALERTS_SHIFTS {
    SHOCK_DETECTED,
    MOTION_STARTED,
    MOTION_STOPPED,
    GEOFENCE_ENTERED,
    GEOFENCE_EXITED,
    TEMPER_HIGH,
    TEMPER_LOW,
    BATTERY_LOW,
    ALERTS_MAX
};

// Init Impossible temperature value 
const INIT_TEMPER_VALUE = -300;

// Init latitude value (North Pole)
const INIT_LATITUDE = 90.0;

// Init longitude value (Greenwich)
const INIT_LONGITUDE = 0.0;

// Temperature hysteresis
const TEMPER_HYST = 1;

// Battery level hysteresis
const BATTERY_LEV_HYST = 2;

// Data Processor class.
// Process data, save and send messages
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

    // Accelerometer driver object
    _ad = null;

    // Motion Monitor driver object
    _mm = null;

    // Save message callback
    _saveCb = null;

    // Send message callback
    _sendCb = null;

    // Last temperature value
    _curTemper = null;

    // Last location
    _curLoc = null;

    // Sign of relevance
    _isFreshCurLoc = null;

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

    // Current alert state
    _curAlertState = null;

    // Previous alert state
    _prevAlertState = null;

    // Shock threshold value
    _shockThreshold = null;

    /**
     *  Constructor for Data Processor class.
     *  @param {object} motionMon - Motion monitor object.
     *  @param {object} accelDriver - Accelerometer driver object.
     *  @param {object} temperSens - Temperature sensor driver object.
     *  @param {object} batDriver - Battery driver object.
     */
    constructor(motionMon, accelDriver, temperSens, batDriver) {
        _ad = accelDriver;
        _mm = motionMon;
        _curAlertState = 0;
        _prevAlertState = 0;
        _curBatteryLev = 0;
        _curTemper = INIT_TEMPER_VALUE;
        _inMotion = false;
        _isFreshCurLoc = false;
        _curLoc = {"timestamp": 0,
                   "type": "gnss",
                   "accuracy": 0,
                   "longitude": INIT_LONGITUDE,
                   "latitude": INIT_LATITUDE};
        _alertNames = ["shockDetected",
                       "motionStarted",
                       "motionStopped",
                       "geofenceEntered",
                       "geofenceExited",
                       "temperatureHigh",
                       "temperatureLow",
                       "batteryLow"];
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
     *        The settings:
     *          "temperatureHighAlertThr": {integer} - Temperature high alert threshold, in Celsius.
     *                                          Default: DEFAULT_TEMPERATURE_HIGH
     *           "temperatureLowAlertThr": {integer} - Temperature low alert threshold, in Celsius.
     *                                          Default: DEFAULT_TEMPERATURE_LOW
     *                "dataReadingPeriod": {float} - Data reading period, in seconds.
     *                                          Default: DEFAULT_DATA_READING_PERIOD
     *                "dataSendingPeriod": {float} - Data sending period, in seconds.
     *                                          Default: DEFAULT_DATA_SENDING_PERIOD
     *                    "batteryLowThr": {integer} - Battery low alert threshold
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

        foreach (key, value in dataProcSettings) {
            if (typeof key == "string") {
                if (key == "temperatureHighAlertThr") {
                    if (typeof value == "integer") {
                        _temperatureHighAlertThr = value;
                    } else {
                        ::error("temperatureHighAlertThr incorrect value", "@{CLASS_NAME}.start");
                    }
                }
                if (key == "temperatureLowAlertThr") {
                    if (typeof value == "integer") {
                        _temperatureLowAlertThr = value;
                    } else {
                        ::error("temperatureLowAlertThr incorrect value", "@{CLASS_NAME}.start");
                    }
                }
                if (key == "dataReadingPeriod") {
                    if (typeof value == "float") {
                        _dataReadingPeriod = value;
                    } else {
                        ::error("dataReadingPeriod incorrect value", "@{CLASS_NAME}.start");
                    }
                }
                if (key == "dataSendingPeriod") {
                    if (typeof value == "float") {
                        _dataSendingPeriod = value;
                    } else {
                        ::error("dataSendingPeriod incorrect value", "@{CLASS_NAME}.start");
                    }
                }
                if (key == "batteryLowThr") {
                    if (typeof value == "integer") {
                        _batteryLowThr = value;
                    } else {
                        ::error("batteryLowThr incorrect value", "@{CLASS_NAME}.start");
                    }
                }
                if (key == "shockThreshold") {
                    if (typeof value == "float" && value > 0.0) {
                        _shockThreshold = value;
                    } else {
                        ::error("shockThreshold incorrect value", "@{CLASS_NAME}.start");
                    }
                }
            } else {
                ::error("Incorrect settings", "@{CLASS_NAME}.start");
                return;
            }
        }

        if (_ad) {
            _ad.enableShockDetection(_onShockDetectedEvent.bindenv(this), {"shockThreshold" : _shockThreshold});
        } else {
            ::info("Accelerometer driver object is null", "@{CLASS_NAME}.start");
        }

        if (_mm) {
            _mm.setNewLocationCb(_onNewLocation.bindenv(this));
            _mm.setMotionEventCb(_onMotionEvent.bindenv(this));
            _mm.setGeofencingEventCb(_onGeofencingEvent.bindenv(this));
        } else {
            ::info("Motion monitor object is null", "@{CLASS_NAME}.start");
        }

        _dataReadingTimer = imp.wakeup(_dataReadingPeriod, _dataProcCb.bindenv(this));
        _dataSendingTimer = imp.wakeup(_dataSendingPeriod, _dataSendCb.bindenv(this));
    }

    /**
     *  Set data saving callback function.
     *  @param {function} saveCb - The callback will be called every time the data is ready to be saved.
     *              saveCb(msg), where
     *                 @param {table} msg - Parameter table.
     *                      The fields:
     *                          "trackerId": {string}   - Imp deviceId.
     *                          "timestamp": {integer}  - The number of seconds that have elapsed since midnight on 1 January 1970.
     *                             "status": {table}    - Table with motion sign
     *                           "location": {table}    - Table with location parameters
     *                            "sensors": {table}    - Table with sensor parameters
     *                             "alerts": {array}    - Alerts array
     */
    function setDataSavingCb(saveCb) {
        if (typeof saveCb == "function" || saveCb == null) {
            _saveCb = saveCb;
        } else {
            ::error("Argument not a function or null", "@{CLASS_NAME}.setDataSavingCb");
        }
    }

    /**
     *  Set data sending callback function.
     *  @param {function} sendCb - The callback will be called every time there is a time to send data.
     *              sendCb(msg), where
     *                 @param {table} msg - Parameter table.
     *                      The fields:
     *                          "trackerId": {string}   - Imp deviceId.   
     *                          "timestamp": {integer}  - The number of seconds that have elapsed since midnight on 1 January 1970.
     *                             "status": {table}    - Table with motion sign
     *                           "location": {table}    - Table with location parameters
     *                            "sensors": {table}    - Table with sensor parameters
     *                             "alerts": {array}    - Alerts array
     */
    function setDataSendingCb(sendCb) {
        if (typeof sendCb == "function" || sendCb == null) {
            _sendCb = sendCb;
        } else {
            ::error("Argument not a function or null", "@{CLASS_NAME}.setDataSendingCb");
        }
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     *  Data sending timer callback function.
     */
    function _dataSendCb() {
        _dataSend();
    }

    /**
     *  Data sending function.
     */
    function _dataSend(msg) {

        _dataSendingTimer && imp.cancelwakeup(_dataSendingTimer);

        if (_sendCb) {
            _sendCb(msg);
        }

        _dataSendingTimer = imp.wakeup(_dataSendingPeriod, _dataSendCb.bindenv(this));
    }

    /**
     *  Data reading timer callback function.
     */
    function _dataProcCb() {
        _dataProc();
    }

    /**
     *  Data reading and alert polling.
     */
    function _dataProc() {

        _dataReadingTimer && imp.cancelwakeup(_dataReadingTimer);

        if (_curTemper > _temperatureHighAlertThr) {
            _curAlertState = _curAlertState | (1 << ALERTS_SHIFTS.TEMPER_HIGH);
        }

        if (_curTemper < _temperatureHighAlertThr - TEMPER_HYST) {
            _curAlertState = _curAlertState & ~(1 << ALERTS_SHIFTS.TEMPER_HIGH);
        }

        if (_curTemper < _temperatureLowAlertThr) {
            _curAlertState = _curAlertState | (1 << ALERTS_SHIFTS.TEMPER_LOW);
        }

        if (_curTemper > _temperatureLowAlertThr + TEMPER_HYST) {
            _curAlertState = _curAlertState & ~(1 << ALERTS_SHIFTS.TEMPER_LOW);
        }

        if (_curBatteryLev < _batteryLowThr) {
            _curAlertState = _curAlertState | (1 << ALERTS_SHIFTS.BATTERY_LOW);
        }
        
        if (_curBatteryLev > _batteryLowThr + BATTERY_LEV_HYST) {
            _curAlertState = _curAlertState & ~(1 << ALERTS_SHIFTS.BATTERY_LOW);
        }

        local alerts = [];
        if (_prevAlertState != _curAlertState) {
            for (local bitCntr = ALERTS_SHIFTS.SHOCK_DETECTED; bitCntr < ALERTS_SHIFTS.ALERTS_MAX; bitCntr++) {
                // Alert event happens in case of a transition: non-alert condition (at the previous reading) -> alert condition (at the current reading)
                if (!(_prevAlertState & (1 << bitCntr)) && (_curAlertState & (1 << bitCntr))) {
                    alerts.append(_alertNames[bitCntr]);
                    // resetting shock immediately after detection 
                    if (bitCntr == ALERTS_SHIFTS.SHOCK_DETECTED) {
                        _curAlertState = _curAlertState & ~(1 << ALERTS_SHIFTS.SHOCK_DETECTED);
                    }
                }
            }
        }

        local msg = {"trackerId":hardware.getdeviceid(),
                     "timestamp": time(),
                     "status":{"inMotion":_inMotion},
                               "location":{"fresh":_isFreshCurLoc,
                               "timestamp": _curLoc.timestamp,
                               "type": _curLoc.type,
                               "accuracy": _curLoc.accuracy,
                               "lng": _curLoc.longitude,
                               "lat": _curLoc.latitude},
                     "sensors":{"batteryLevel": _curBatteryLev,
                                "temperature": _curTemper},
                     "alerts":alerts};
        
        ::info("Message:", "@{CLASS_NAME}._dataProc");
        ::info("trackerId: " + msg.trackerId + "timestamp: " + msg.timestamp +
               "inMotion: " + msg.inMotion + "fresh" + msg.fresh + 
               "location timestamp: " + _curLoc.timestamp + "type" + 
               _curLoc.type + "accuracy: " + _curLoc.accuracy + 
               "lng: " + _curLoc.longitude + "lat" + _curLoc.latitude + 
               "batteryLevel: " + _curBatteryLev + "temperature" + 
               _curTemper, "@{CLASS_NAME}._dataProc");
        ::info("Alerts:", "@{CLASS_NAME}._dataProc");
        foreach (item in alerts) {
            ::info(item, "@{CLASS_NAME}._dataProc");
        }

        if (_saveCb) {
            _saveCb(msg);
        }

        // If there is at least one alert event call data sending function
        if (alerts.len() > 0) {
            _dataSend(msg);
        }

        _prevAlertState = _curAlertState;
        
        _dataReadingTimer = imp.wakeup(_dataReadingPeriod, _dataProcCb.bindenv(this));
    }

    /**
     *  The handler is called when a new temperature value is received.
     *  @param {float} temperVal - Temperature value.
     */
    function _onNewTemperValue(temperVal) {
        if (typeof temperVal == "float") {
            _curTemper = temperVal;
        } else {
            ::error("Error type of temperature value", "@{CLASS_NAME}._onNewTemperValue");
        }
    }

    /**
     *  The handler is called when a new location is received.
     *  @param {bool} isFresh - false if the latest location has not beed determined, the provided data is the previous location
     *  @param {table} loc - New location table.
     *      The fields:
     *          "timestamp": {integer}  - Time value
     *               "type": {string}   - gnss or cell e.g.
     *           "accuracy": {integer}  - Accuracy in meters
     *          "longitude": {float}    - Longitude in degrees
     *           "latitude": {float}    - Latitude in degrees
     */
    function _onNewLocation(isFresh, loc) {
        if (typeof loc == "table" && typeof isFresh == "bool") {
            _isFreshCurLoc = isFresh;
            _curLoc = loc;
        } else {
            ::error("Error type of location value", "@{CLASS_NAME}._onNewLocation");
        }
    }

    /**
     *  The handler is called when a new battery level is received.
     *  @param {float} lev - Сharge level in percent.
     */
    function _onNewBatteryLevel(lev) {
        if (typeof lev == "float") {
            _curBatteryLev = lev;
        } else {
            ::error("Error type of battery level", "@{CLASS_NAME}._onNewBatteryLevel");
        }
    }

    /**
     * The handler is called when a new shock event is detected.
     */
    function _onShockDetectedEvent() {
        _curAlertState = _curAlertState | (1 << ALERTS_SHIFTS.SHOCK_DETECTED);
        _dataProc();
    }

    /**
     *  The handler is called when a new motion event is detected.
     *  @param {bool} eventType - If true - in motion.
     */
    function _onMotionEvent(eventType) {
        if (eventType) {
            _curAlertState = _curAlertState | (1 << ALERTS_SHIFTS.MOTION_STARTED);
            _curAlertState = _curAlertState & ~(1 << ALERTS_SHIFTS.MOTION_STOPPED);
            _inMotion = true;
        } else {
            _curAlertState = _curAlertState & ~(1 << ALERTS_SHIFTS.MOTION_STARTED);
            _curAlertState = _curAlertState | (1 << ALERTS_SHIFTS.MOTION_STOPPED);
            _inMotion = false;
        }
        _dataProc();
    }

    /**
     *  The handler is called when a new geofencing event is detected.
     *  @param {bool} eventType - If true - geofence entered.
     */
    function _onGeofencingEvent(eventType) {
        if (eventType) {
            _curAlertState = _curAlertState | (1 << ALERTS_SHIFTS.GEOFENCE_ENTERED);
            _curAlertState = _curAlertState & ~(1 << ALERTS_SHIFTS.GEOFENCE_EXITED);
        } else {
            _curAlertState = _curAlertState & ~(1 << ALERTS_SHIFTS.GEOFENCE_ENTERED);
            _curAlertState = _curAlertState | (1 << ALERTS_SHIFTS.GEOFENCE_EXITED);
        }
        _dataProc();
    }
}

@set CLASS_NAME = null // Reset the variable