@set CLASS_NAME = "MotionMonitor" // Class name for logging

// Mean earth radius in meters (https://en.wikipedia.org/wiki/Great-circle_distance)
const MM_EARTH_RAD = 6371009;

// min longitude
const MM_MIN_LNG = -180.0;
// max latitude
const MM_MAX_LNG = 180.0;
// min latitude
const MM_MIN_LAT = -90.0;
// max latitude
const MM_MAX_LAT = 90.0;

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

    // geofence zone center location
    _geofenceCenter = null;

    // geofence zone radius
    _geofenceRadius = null;

    // enable/disable flag
    _geofenceIsEnable = null;

    // in zone or not
    _inGeofenceZone = null;

    /**
     *  Constructor for Motion Monitor class.
     *  @param {object} accelDriver - Accelerometer driver object.
     *  @param {object} locDriver - Location driver object.
     */
    constructor(accelDriver, locDriver) {
        _ad = accelDriver;
        _ld = locDriver;

        _geofenceIsEnable = false;
        _geofenceRadius = 0.0;
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
        _geofenceCenter = {"longitude": INIT_LONGITUDE,
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

        // check and set the settings
        _checkMotionMonSettings(motionMonSettings);

        // get current location
        _locReading();

        // initial state after start: not in motion
        _motionStopAssumption = false;
        _inMotion = false;

        // detect motion start
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
     *                 locCb(loc), where
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

    /**
     *  Enable/disable and set settings for geofencing.
     *  @param {table} settings - Table with the center coordinates of geofence zone, radius.
     *      The settings include:
     *          "enabled"   : {bool}  - Enable/disable, true - geofence is enabled.
     *          "lng"       : {float} - Center longitude, in degrees.
     *          "lat"       : {float} - Center latitude, in degrees.
     *          "radius"    : {float} - Radius, in meters. (value must exceed the accuracy of the coordinate)
     */
    function configureGeofence(settings) {
        // reset in zone flag
        _inGeofenceZone = null;
        if (settings != null && typeof settings == "table") {
            _geofenceIsEnable = false;
            if ("enabled" in settings) {
                if (typeof settings.enabled == "bool") {
                    ::info("Geofence is " + (settings.enabled ? "enabled" : "disabled"), "@{CLASS_NAME}");
                    _geofenceIsEnable = settings.enabled;
                }
            }
            _geofenceRadius = 0.0;
            if ("radius" in settings) {
                if (typeof settings.radius == "float" && 
                    settings.radius >= 0) {
                    ::info("Geofence radius: " + settings.radius, "@{CLASS_NAME}");
                    _geofenceRadius = settings.radius > MM_EARTH_RAD ? MM_EARTH_RAD : settings.radius;
                }
            }
            _geofenceCenter = {"longitude": INIT_LONGITUDE,
                               "latitude" : INIT_LATITUDE};
            if ("lng" in settings && "lat" in settings) {
                if (typeof settings.lat == "float") {
                    ::info("Geofence latitude: " + settings.lat, "@{CLASS_NAME}");
                    _geofenceCenter.latitude = settings.lat;
                    if (_geofenceCenter.latitude < MM_MIN_LAT) {
                        ::error("Geofence latitude not in range [-90;90]: " + settings.lat, "@{CLASS_NAME}");
                        _geofenceCenter.latitude = MM_MIN_LAT;
                    }
                    if (_geofenceCenter.latitude > MM_MAX_LAT) {
                        ::error("Geofence latitude not in range [-90;90]: " + settings.lat, "@{CLASS_NAME}");
                        _geofenceCenter.latitude = MM_MAX_LAT;
                    }
                    ::info("Geofence longitude: " + settings.lng, "@{CLASS_NAME}");
                    _geofenceCenter.longitude = settings.lng;
                    if (_geofenceCenter.longitude < MM_MIN_LNG) {
                        ::error("Geofence longitude not in range [-180;180]: " + settings.lng, "@{CLASS_NAME}");
                        _geofenceCenter.longitude = MM_MIN_LAT;
                    }
                    if (_geofenceCenter.longitude > MM_MAX_LAT) {
                        ::error("Geofence longitude not in range [-180;180]: " + settings.lng, "@{CLASS_NAME}");
                        _geofenceCenter.longitude = MM_MAX_LAT;
                    }
                }
            }
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
            // read location and, after that, check if it is the same as the previous one
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
            _newLocCb && _newLocCb(_curLoc);
            _procGeofence(loc);
        }.bindenv(this), function(_) {
            _locReadingPromise = null;

            // the current location becomes non-fresh
            _curLoc = _prevLoc;
            _curLocFresh = false;
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
                dist = _greatCircleDistance(_curLoc, _prevLoc);
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

    /**
     *  Zone border crossing check.
     *  
     *   @param {table} curLocation - Table with the current location.
     *        The table must include parts:
     *          "accuracy" : {integer}  - Accuracy, in meters.
     *          "longitude": {float}    - Longitude, in degrees.
     *          "latitude" : {float}    - Latitude, in degrees.  
     */
    function _procGeofence(curLocation) {
        if (_geofenceIsEnable) {
            local dist = _greatCircleDistance(_geofenceCenter, curLocation);               //       _____GeofenceZone
            ::debug("Geofence distance: " + dist, "@{CLASS_NAME}");                        //      /      \
            if (dist > _geofenceRadius) {                                                  //     / __    R\    dist    __Location
                local distWithoutAccurace = dist - curLocation.accuracy;                   //    | /\ \ .---|----------/- \
                if (distWithoutAccurace > 0 && distWithoutAccurace > _geofenceRadius) {    //    | \__/     |          \_\/acc.
                    if (_inGeofenceZone == null || _inGeofenceZone == true) {              //     \ Location/
                        _geofencingEventCb && _geofencingEventCb(false);                   //      \______ /
                        _inGeofenceZone = false;                                           //       
                    }                                                                      //
                }
            } else {
                local distWithAccurace = dist + curLocation.accuracy;
                if (distWithAccurace <= _geofenceRadius) {
                    if (_inGeofenceZone == null || _inGeofenceZone == false) {
                        _geofencingEventCb && _geofencingEventCb(true);
                        _inGeofenceZone = true;
                    }
                }
            }
        }
    }

    /**
     *  Calculate distance between two locations.
     *
     *   @param {table} locationFirstPoint - Table with the first location value.
     *        The table must include parts:
     *          "longitude": {float} - Longitude, in degrees.
     *          "latitude":  {float} - Latitude, in degrees.
     *   @param {table} locationSecondPoint - Table with the second location value.
     *        The location must include parts:
     *          "longitude": {float} - Longitude, in degrees.
     *          "latitude":  {float} - Latitude, in degrees.
     *  
     *   @return {float} If success - value, else - default value (0).
     */
    function _greatCircleDistance(locationFirstPoint, locationSecondPoint) {
        local dist = 0;

        if (locationFirstPoint != null || locationSecondPoint != null) {
            if ("longitude" in locationFirstPoint &&
                "longitude" in locationSecondPoint &&
                "latitude" in locationFirstPoint &&
                "latitude" in locationSecondPoint) {
                // https://en.wikipedia.org/wiki/Great-circle_distance
                local deltaLat = math.fabs(locationFirstPoint.latitude - 
                                           locationSecondPoint.latitude)*PI/180.0;
                local deltaLong = math.fabs(locationFirstPoint.longitude - 
                                            locationSecondPoint.longitude)*PI/180.0;
                //  -180___180 
                //     / | \
                //west|  |  |east   selection of the shortest arc
                //     \_|_/ 
                // Earth 0 longitude
                if (deltaLong > PI) {
                    deltaLong = 2*PI - deltaLong;
                }
                local deltaSigma = math.pow(math.sin(0.5*deltaLat), 2);
                deltaSigma += math.cos(locationFirstPoint.latitude*PI/180.0)*
                              math.cos(locationSecondPoint.latitude*PI/180.0)*
                              math.pow(math.sin(0.5*deltaLong), 2);
                deltaSigma = 2*math.asin(math.sqrt(deltaSigma));

                // actual arc length on a sphere of radius r (mean Earth radius)
                dist = MM_EARTH_RAD*deltaSigma;
            }
        }

        return dist
    }
}

@set CLASS_NAME = null // Reset the variable
