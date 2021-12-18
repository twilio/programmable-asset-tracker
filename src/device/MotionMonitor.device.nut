@set CLASS_NAME = "MotionMonitor" // Class name for logging

// Mean earth radius in meters (https://en.wikipedia.org/wiki/Great-circle_distance)
const MM_EARTH_RAD = 6371009;

// Motion Monitor class.
// Starts and stops motion monitoring.
class MotionMonitor {

    // Accelerometer driver object
    _ad = null;

    // Location driver object
    _ld = null;

    // New location callback function
    _newLocCb = null;

    // Motion event callback function
    _motionEventCb = null;

    // Geofencing event callback function
    _geofencingEventCb = null;

    // Location reading timer period
    _locReadingPeriod = null;

    // Location reading timer
    _locReadingTimer = null;

    // Promise of the location reading process or null
    _locReadingPromise = null;

    // Motion stop assumption
    _motionStopAssumption = null;

    // Moton state
    _inMotion = null;

    // Current location
    _curLoc = null;

    // Sign of the current location relevance
    _curLocFresh = null;

    // Previous location
    _prevLoc = null;

    // Sign of the previous location relevance
    _prevLocFresh = null;

    // Movement acceleration threshold range: maximum level
    _movementMax = null;

    // Movement acceleration threshold range: minimum (starting) level
    _movementMin = null;

    // Duration of exceeding movement acceleration threshold
    _movementDur = null;

    // Maximum time to determine motion detection after the initial movement
    _motionTimeout = null;

    // Minimal instantaneous velocity to determine motion detection condition
    _motionVelocity = null;

    // Minimal movement distance to determine motion detection condition
    _motionDistance = null;

    /**
     *  Constructor for Motion Monitor class.
     *  @param {object} accelDriver - Accelerometer driver object.
     *  @param {object} locDriver - Location driver object.
     */
    constructor(accelDriver, locDriver) {
        _ad = accelDriver;
        _ld = locDriver;

        _motionStopAssumption = false;
        _inMotion = false;
        _curLocFresh = false;
        _prevLocFresh = false;
        _curLoc = {"timestamp": 0,
                   "type": "gnss",
                   "accuracy": MM_EARTH_RAD,
                   "longitude": INIT_LONGITUDE,
                   "latitude": INIT_LATITUDE};
        _prevLoc = {"timestamp": 0,
                    "type": "gnss",
                    "accuracy": MM_EARTH_RAD,
                    "longitude": INIT_LONGITUDE,
                    "latitude": INIT_LATITUDE};
        _locReadingPeriod = DEFAULT_LOCATION_READING_PERIOD;
        _movementMax = DEFAULT_MOVEMENT_ACCELERATION_MAX;
        _movementMin = DEFAULT_MOVEMENT_ACCELERATION_MIN;
        _movementDur = DEFAULT_MOVEMENT_ACCELERATION_DURATION;
        _motionTimeout = DEFAULT_MOTION_TIME;
        _motionVelocity = DEFAULT_MOTION_VELOCITY;
        _motionDistance = DEFAULT_MOTION_DISTANCE;
    }

    /**
     *   Start motion monitoring.
     *   @param {table} motionMonSettings - Table with the settings.
     *        Optional, all settings have defaults.
     *        If a setting is missed, it is reset to default.
     *        The settings:
     *          "locReadingPeriod": {float} - Location reading period, in seconds.
     *                                          Default: DEFAULT_LOCATION_READING_PERIOD
     *          "movementMax": {float}    - Movement acceleration maximum threshold, in g.
     *                                        Default: DEFAULT_MOVEMENT_ACCELERATION_MAX
     *          "movementMin": {float}    - Movement acceleration minimum threshold, in g.
     *                                        Default: DEFAULT_MOVEMENT_ACCELERATION_MIN
     *          "movementDur": {float}    - Duration of exceeding movement acceleration threshold, in seconds.
     *                                        Default: DEFAULT_MOVEMENT_ACCELERATION_DURATION
     *          "motionTimeout": {float}  - Maximum time to determine motion detection after the initial movement, in seconds.
     *                                        Default: DEFAULT_MOTION_TIME
     *          "motionVelocity": {float} - Minimum instantaneous velocity  to determine motion detection condition, in meters per second.
     *                                        Default: DEFAULT_MOTION_VELOCITY
     *          "motionDistance": {float} - Minimal movement distance to determine motion detection condition, in meters.
     *                                      If 0, distance is not calculated (not used for motion detection).
     *                                        Default: DEFAULT_MOTION_DISTANCE
     */
    function start(motionMonSettings = {}) {
        _locReadingPeriod = DEFAULT_LOCATION_READING_PERIOD;
        _movementMax = DEFAULT_MOVEMENT_ACCELERATION_MAX;
        _movementMin = DEFAULT_MOVEMENT_ACCELERATION_MIN;
        _movementDur = DEFAULT_MOVEMENT_ACCELERATION_DURATION;
        _motionTimeout = DEFAULT_MOTION_TIME;
        _motionVelocity = DEFAULT_MOTION_VELOCITY;
        _motionDistance = DEFAULT_MOTION_DISTANCE;

        // Check and set the settings
        _checkMotionMonSettings(motionMonSettings);

        // get current location
        _locReading();
        // check - not in motion
        _ad.detectMotion(_onAccelMotionDetected.bindenv(this), {"movementMax"      : _movementMax,
                                                                "movementMin"      : _movementMin,
                                                                "movementDur"      : _movementDur,
                                                                "motionTimeout"    : _motionTimeout,
                                                                "motionVelocity"   : _motionVelocity,
                                                                "motionDistance"   : _motionDistance});
    }

    /**
     *   Stop motion monitoring.
     */
    function stop() {
        _locReadingTimer && imp.cancelwakeup(_locReadingTimer);
    }

    /**
     *  Set new location callback function.
     *  @param {function | null} locCb - The callback will be called every time the new location is received (null - disables the callback)
     *                 locCb(isFresh, loc), where
     *                 @param {bool} isFresh - false if the latest location has not beed determined, the provided data is the previous location
     *                 @param {table} loc - Location information
     *                      The fields:
     *                          "timestamp": {integer}  - The number of seconds that have elapsed since midnight on 1 January 1970.
     *                               "type": {string}   - "gnss", "cell", "wifi", "ble"
     *                           "accuracy": {integer}  - Accuracy in meters
     *                          "longitude": {float}    - Longitude in degrees
     *                           "latitude": {float}    - Latitude in degrees
     */
    function setNewLocationCb(locCb) {
        if (typeof locCb == "function" || locCb == null) {
            _newLocCb = locCb;
        } else {
            ::error("Argument not a function or null", "@{CLASS_NAME}");
        }
    }

    /**
     *  Set motion event callback function.
     *  @param {function | null} motionEventCb - The callback will be called every time the new motion event is detected (null - disables the callback)
     *                 motionEventCb(ev), where
     *                 @param {bool} ev - true: motion started, false: motion stopped
     */
    function setMotionEventCb(motionEventCb) {
        if (typeof motionEventCb == "function" || motionEventCb == null) {
            _motionEventCb = motionEventCb;
        } else {
            ::error("Argument not a function or null", "@{CLASS_NAME}");
        }
    }

    /**
     *  Set geofencing event callback function.
     *  @param {function | null} geofencingEventCb - The callback will be called every time the new geofencing event is detected (null - disables the callback)
     *                 geofencingEventCb(ev), where
     *                 @param {bool} ev - true: geofence entered, false: geofence exited
     */
    function setGeofencingEventCb(geofencingEventCb) {
        if (typeof geofencingEventCb == "function" || geofencingEventCb == null) {
            _geofencingEventCb = geofencingEventCb;
        } else {
            ::error("Argument not a function or null", "@{CLASS_NAME}");
        }
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Check settings element.
     * Returns the specified value if the check fails.
     *
     * @param {float} val - Value of settings element.
     * @param {float} defVal - Default value of settings element.
     * @param {bool} flCheckSignEq - Flag for sign check.
     *
     * @return {float} If success - value, else - default value.
     */
    function _checkVal(val, defVal, flCheckSignEq = true) {
        if (typeof val == "float") {
            if (flCheckSignEq) {
                if (val >= 0.0) {
                    return val;
                }
            } else {
                if (val > 0.0) {
                    return val;
                }
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
     *   @param {table} motionMonSettings - Table with the settings.
     *        Optional, all settings have defaults.
     *        The settings:
     *          "locReadingPeriod": {float} - Location reading period, in seconds.
     *                                          Default: DEFAULT_LOCATION_READING_PERIOD
     *          "movementMax": {float}    - Movement acceleration maximum threshold, in g.
     *                                        Default: DEFAULT_MOVEMENT_ACCELERATION_MAX
     *          "movementMin": {float}    - Movement acceleration minimum threshold, in g.
     *                                        Default: DEFAULT_MOVEMENT_ACCELERATION_MIN
     *          "movementDur": {float}    - Duration of exceeding movement acceleration threshold, in seconds.
     *                                        Default: DEFAULT_MOVEMENT_ACCELERATION_DURATION
     *          "motionTimeout": {float}  - Maximum time to determine motion detection after the initial movement, in seconds.
     *                                        Default: DEFAULT_MOTION_TIME
     *          "motionVelocity": {float} - Minimum instantaneous velocity  to determine motion detection condition, in meters per second.
     *                                        Default: DEFAULT_MOTION_VELOCITY
     *          "motionDistance": {float} - Minimal movement distance to determine motion detection condition, in meters.
     *                                      If 0, distance is not calculated (not used for motion detection).
     *                                        Default: DEFAULT_MOTION_DISTANCE
     */
    function _checkMotionMonSettings(motionMonSettings) {
        foreach (key, value in motionMonSettings) {
            if (typeof key == "string") {
                switch(key){
                    case "locReadingPeriod":
                        _locReadingPeriod = _checkVal(value, DEFAULT_LOCATION_READING_PERIOD);
                        break;
                    case "movementMax":
                        _movementMax = _checkVal(value, DEFAULT_MOVEMENT_ACCELERATION_MAX, false);
                        break;
                    case "movementMin":
                        _movementMin = _checkVal(value, DEFAULT_MOVEMENT_ACCELERATION_MIN, false);
                        break;
                    case "movementDur":
                        _movementDur = _checkVal(value, DEFAULT_MOVEMENT_ACCELERATION_DURATION, false);
                        break;
                    case "motionTimeout":
                        _motionTimeout = _checkVal(value, DEFAULT_MOTION_TIME, false);
                        break;
                    case "motionVelocity":
                        _motionVelocity = _checkVal(value, DEFAULT_MOTION_VELOCITY);
                        break;
                    case "motionDistance":
                        _motionDistance = _checkVal(value, DEFAULT_MOTION_DISTANCE);
                        break;
                    default:
                        ::error("Incorrect key name", "@{CLASS_NAME}");
                        break;
                }
            } else {
                ::error("Incorrect motion condition settings", "@{CLASS_NAME}");
            }
        }
    }

    /**
     *  Location reading timer callback function.
     */
    function _locReadingTimerCb() {
        local start = hardware.millis();

        if (_motionStopAssumption) {
            // no movement during location reading period =>
            // motion stop is confirmed
            _inMotion = false;
            _motionStopAssumption = false;
            if (_motionEventCb) {
                _motionEventCb(_inMotion);
            }
        } else {
            _locReading()
            .finally(function(_) {
                _checkMotionStop();

                // Calculate the delay for the timer according to the time spent on location reading and etc.
                local delay = _locReadingPeriod - (hardware.millis() - start) / 1000.0;
                _locReadingTimer && imp.cancelwakeup(_locReadingTimer);
                _locReadingTimer = imp.wakeup(delay, _locReadingTimerCb.bindenv(this));
            }.bindenv(this));
        }
    }

    /**
     *  Try to determine the current location
     */
    function _locReading() {
        if (_locReadingPromise) {
            return _locReadingPromise;
        }

        _prevLoc = _curLoc;
        _prevLocFresh = _curLocFresh;

        ::debug("Getting location..", "@{CLASS_NAME}");

        return _locReadingPromise = _ld.getLocation()
        .then(function(loc) {
            _locReadingPromise = null;

            _curLoc = loc;
            _curLocFresh = true;
            _newLocCb && _newLocCb(_curLocFresh, _curLoc);
        }.bindenv(this), function(_) {
            _locReadingPromise = null;

            // the current location becomes non-fresh
            _curLoc = _prevLoc;
            _curLocFresh = false;
            // in cb location null check exist
            _newLocCb && _newLocCb(_curLocFresh, _curLoc);
        }.bindenv(this));
    }

    /**
     *  Check if the motion is stopped
     */
    function _checkMotionStop() {
        if (_curLocFresh) {

            local dist = 0;
            if (_curLoc && _prevLoc) {
                // calculate distance between two locations
                // https://en.wikipedia.org/wiki/Great-circle_distance
                local deltaLat = math.fabs(_curLoc.latitude - _prevLoc.latitude)*PI/180.0;
                local deltaLong = math.fabs(_curLoc.longitude - _prevLoc.longitude)*PI/180.0;
                local deltaSigma = math.pow(math.sin(0.5*deltaLat), 2);
                deltaSigma += math.cos(_curLoc.latitude*PI/180.0)*
                              math.cos(_prevLoc.latitude*PI/180.0)*
                              math.pow(math.sin(0.5*deltaLong), 2);
                deltaSigma = 2*math.asin(math.sqrt(deltaSigma));

                // actual arc length on a sphere of radius r (mean Earth radius)
                dist = MM_EARTH_RAD*deltaSigma;
            } else {
                ::error("Location is null", "@{CLASS_NAME}");
            }
            ::debug("Distance: " + dist, "@{CLASS_NAME}");

            // check if the distance is less than 2 radius of accuracy
            if (dist < 2*_curLoc.accuracy) {
                // maybe motion is stopped, need to double check
                _motionStopAssumption = true;
            } else {
                // still in motion
                if (!_inMotion) {
                    _inMotion = true;
                    _motionEventCb && _motionEventCb(_inMotion);
                }
            }
        }

        if (!_curLocFresh && !_prevLocFresh) {
            // the location has not been determined two times in a raw,
            // need to double check the motion
            _motionStopAssumption = true;
        }

        if(_motionStopAssumption) {
            // enable motion detection by accelerometer to double check the motion
            _ad.detectMotion(_onAccelMotionDetected.bindenv(this), {"movementMax"      : _movementMax,
                                                                    "movementMin"      : _movementMin,
                                                                    "movementDur"      : _movementDur,
                                                                    "motionTimeout"    : _motionTimeout,
                                                                    "motionVelocity"   : _motionVelocity,
                                                                    "motionDistance"   : _motionDistance});
        }
    }

    /**
     *  The handler is called when the motion is detected by accelerometer
     */
    function _onAccelMotionDetected() {
        _motionStopAssumption = false;
        if (!_inMotion) {
            _inMotion = true;

            // start reading location
            _locReading();
            _motionEventCb && _motionEventCb(_inMotion);

            _locReadingTimer && imp.cancelwakeup(_locReadingTimer);
            _locReadingTimer = imp.wakeup(_locReadingPeriod, _locReadingTimerCb.bindenv(this));
        }
    }
}

@set CLASS_NAME = null // Reset the variable
