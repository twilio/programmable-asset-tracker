@set CLASS_NAME = "MotionMonitor" // Class name for logging

// Mean earth radius in meters (https://en.wikipedia.org/wiki/Great-circle_distance)
const MM_EARTH_RAD = 6371009;

// Motion Monitor class.
//  
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

    // Motion stop assumption
    _motionStopAssumption = null;

    // Moton state
    _inMotion = null;

    // Current location
    _curLoc = null;    

    // Sign of relevance
    _curLocFresh = null;

    // Previous location
    _prevLoc = null;

    // Sign of relevance
    _prevLocFresh = null;

    // maximum value of acceleration threshold for bounce filtering
    _movementMax = null;

    // minimum value of acceleration threshold for bounce filtering
    _movementMin = null;

    // minimum value of acceleration threshold for bounce filtering
    _movementDur = null;

    // maximum time to determine motion detection after the initial movement
    _motionTimeout = null;

    // minimum instantaneous velocity to determine motion detection condition
    _motionVelocity = null;

    // minimal movement distance to determine motion detection condition
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
        _prevLoc = false;
        _curLocFresh = false;   
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

        if(!_checkMotionMonSettings(motionMonSettings))
            return;
        
        _locReadingTimer = imp.wakeup(_locReadingPeriod, _locReadingCb.bindenv(this));
    }

    /**
     *   Stop motion monitoring.     
     */
    function stop() {
        _locReadingTimer && imp.cancelwakeup(_locReadingTimer);
    }

    /**
     *  Set new location callback function.
     *  @param {function | null} locCb - The callback will be called every time the new location is received.
     *                 locCb(loc), where
     *                 @param {bool} isFresh - false if the latest location has not beed determined, the provided data is the previous location
     *                 @param {table} loc - New location table.
     *                      The fields:
     *                          "timestamp": {integer}  - The number of seconds that have elapsed since midnight on 1 January 1970.
     *                               "type": {string}   - gnss or cell e.g.
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
     *  @param {function | null} motionEventCb - The callback will be called every time the new motion event is detected.
     *                 motionEventCb(ev), where
     *                 @param {bool} ev - If true - in motion.     
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
     *  @param {function | null} geofencingEventCb - The callback will be called every time the new geofencing event is detected.
     *                 geofencingEventCb(ev), where
     *                 @param {bool} ev - If true - geofence entered.
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
     *  Check settings.
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
     *   @return {boolean} true if success.
     */
    function _checkMotionMonSettings(motionMonSettings) {
        foreach (key, value in motionMonSettings) {
            if (typeof key == "string") {
                if (key == "locReadingPeriod") {
                    if (typeof value == "float"  && value >= 0) {
                        _locReadingPeriod = value;                        
                    } else {
                        ::error("motionDistance incorrect value. Using default value.", "@{CLASS_NAME}");
                    }
                }

                if (key == "movementMax") {
                    if (typeof value == "float" && value > 0) {
                        _movementMax = value;                
                    } else {
                        ::error("movementMax incorrect value. Using default value.", "@{CLASS_NAME}");
                    }
                }

                if (key == "movementMin") {
                    if (typeof value == "float"  && value > 0) {
                        _movementMin = value;                        
                    } else {
                        ::error("movementMin incorrect value. Using default value.", "@{CLASS_NAME}");
                    }
                }

                if (key == "movementDur") {
                    if (typeof value == "float"  && value > 0) {
                        _movementDur = value;                
                    } else {
                        ::error("movementDur incorrect value. Using default value.", "@{CLASS_NAME}");
                    }
                }

                if (key == "motionTimeout") {
                    if (typeof value == "float"  && value > 0) {
                        _motionTimeout = value;                
                    } else {
                        ::error("motionTimeout incorrect value. Using default value.", "@{CLASS_NAME}");
                    }
                }
                
                if (key == "motionVelocity") {
                    if (typeof value == "float"  && value >= 0) {
                        _motionVelocity = value;                        
                    } else {
                        ::error("motionVelocity incorrect value. Using default value.", "@{CLASS_NAME}");
                    }
                }

                if (key == "motionDistance") {
                    if (typeof value == "float"  && value >= 0) {
                        _motionDistance = value;                        
                    } else {
                        ::error("motionDistance incorrect value. Using default value.", "@{CLASS_NAME}");
                    }
                }
            } else {
                ::error("Incorrect motion condition settings", "@{CLASS_NAME}");
                return false;
            }
        }

        return true;
    }

    /**
     *  Location reading timer callback function.
     */
    function _locReadingCb() {
        if (_motionStopAssumption) {
            _inMotion = false;
            _motionStopAssumption = false;
            if (_motionEventCb) {
                _motionEventCb(_inMotion);
            }
        } else {
            _locReading();
            _checkMotionStop();
            
            _locReadingTimer && imp.cancelwakeup(_locReadingTimer);
            _locReadingTimer = imp.wakeup(_locReadingPeriod, _locReadingCb.bindenv(this));
        }
    }

    /**
     *  Try to determine the current location in the following order (till successfully determined):
     *     1)  By GNSS fix  
     *     2)  By Cellular info
     */
    function _locReading() {
        _prevLoc = _curLoc;
        _ld.getLocation()
        .then(function(loc) {
            _curLoc = loc;
            _curLocFresh = true;
            if (_newLocCb) {
                _newLocCb(_curLocFresh, _curLoc);
            }
        }.bindenv(this))
        .fail(function(reason) {
            _curLoc = _prevLoc;
            _curLocFresh = false;
            if (_newLocCb) {
                _newLocCb(_curLocFresh, _curLoc);
            }
        }.bindenv(this));
    }

    /**
     *  Calculate distance between two points and comparison with threshold value.
     */
    function _checkMotionStop() {        
        if (_curLocFresh && _prevLocFresh) {
            // https://en.wikipedia.org/wiki/Great-circle_distance
            local deltaLat = math.fabs((_curLoc.latitude - _prevLoc.latitude)*180.0/PI);
            local deltaLong = math.fabs((_curLoc.longitude - _prevLoc.longitude)*180.0/PI);
            local deltaSigma = math.pow(math.sin(0.5*deltaLat, 2));
            deltaSigma += math.cos(_curLoc.latitude*180.0/PI)*math.cos(_prevLoc.latitude*180.0/PI)*math.pow(math.sin(0.5*deltaLong, 2));
            deltaSigma = 2*math.asin(math.sqrt(deltaSigma));
            
            // actual arc length on a sphere of radius r (mean Earth radius)
            local dist = EARTH_RAD*deltaSigma;
            
            // stop assumption if distance less 2 radius of accuracy 
            if (dist < 2*_curLoc.accuracy) {
                _motionStopAssumption = true;                
            }
        }

        if (!_curLocFresh && !_prevLocFresh) {
            _motionStopAssumption = true;            
        }

        if(_motionStopAssumption) {
            _ad.detectMotion(_onAccelMotionDetected.bindenv(this), {"movementMax"      : _movementMax,
                                                                    "movementMin"      : _movementMin,
                                                                    "movementDur"      : _movementDur,
                                                                    "motionTimeout"    : _motionTimeout,
                                                                    "motionVelocity"   : _motionVelocity,
                                                                    "motionDistance"   : _motionDistance});
        }
    }
    
    /**
     *  The handler is called when a accelerometer motion detected.
     */
    function _onAccelMotionDetected() {
        _motionStopAssumption = false;
        if (!_inMotion) {
            _inMotion = true;
            _locReadingTimer && imp.cancelwakeup(_locReadingTimer);            
            _locReading();
            if (_motionEventCb) {
                _motionEventCb(_inMotion);
            }
            _locReadingTimer = imp.wakeup(_locReadingPeriod, _locReadingCb.bindenv(this));
        }
    }
}

@set CLASS_NAME = null // Reset the variable