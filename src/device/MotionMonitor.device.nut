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
    _motionStopAssumption = false;

    // Motion state: true (in motion) / false (not in motion) / null (feature disabled)
    _inMotion = null;

    // Current location
    _curLoc = null;

    // Sign of the current location relevance
    _curLocFresh = false;

    // Previous location
    _prevLoc = null;

    // Sign of the previous location relevance
    _prevLocFresh = false;

    // TODO: Comment
    _motionMonitoringEnabled = false;

    // TODO: Comment
    _accelDetectMotionParams = null;

    // geofence zone center location
    _geofenceCenter = null;

    // geofence zone radius
    _geofenceRadius = null;

    // enable/disable flag
    _geofenceEnabled = false;

    // Geofence state: true (in zone) / false (out of zone) / null (feature disabled)
    _inGeofenceZone = null;

    /**
     *  Constructor for Motion Monitor class.
     *  @param {object} accelDriver - Accelerometer driver object.
     *  @param {object} locDriver - Location driver object.
     */
    constructor(accelDriver, locDriver) {
        _ad = accelDriver;
        _ld = locDriver;

        _curLoc = _ld.lastKnownLocation() || {
            "timestamp": 0,
            "type": "gnss",
            "accuracy": MM_EARTH_RAD,
            "longitude": INIT_LONGITUDE,
            "latitude": INIT_LATITUDE
        };
        _prevLoc = clone _curLoc;
    }

    /**
     *  Start motion monitoring.
     *  @param {table} cfg - Table with the full configuration.
     *                       For details, please, see the documentation
     */
    function start(cfg) {
        updateCfg(cfg);

        // get current location
        _locReading();

        return Promise.resolve(null);
    }

    // TODO: Comment
    function updateCfg(cfg) {
        _updCfgGeneral(cfg);
        _updCfgMotionMonitoring(cfg);
        _updCfgBLEDevices(cfg);
        _updCfgGeofence(cfg);

        return Promise.resolve(null);
    }

    // TODO: Comment
    function getStatus() {
        local res = {
            "flags": {},
            "location": clone _curLoc
        };

        (_inMotion != null) && (res.flags.inMotion <- _inMotion);
        (_inGeofenceZone != null) && (res.flags.inGeofence <- _inGeofenceZone);

        return res;
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

    // TODO: Comment
    function _updCfgGeneral(cfg) {
        _locReadingPeriod = getValFromTable(cfg, "locationTracking/locReadingPeriod", _locReadingPeriod);
        // TODO: What else to do? May need improvements once alwaysOn feature is implemented
    }

    // TODO: Comment
    function _updCfgMotionMonitoring(cfg) {
        local detectMotionParamNames = ["movementAccMin", "movementAccMax", "movementAccDur",
                                        "motionTime", "motionVelocity", "motionDistance"];

        local motionMonitoringCfg = getValFromTable(cfg, "locationTracking/motionMonitoring");
        local newDetectMotionParams = nullEmpty(getValsFromTable(motionMonitoringCfg, detectMotionParamNames));
        // Can be: true/false/null
        local enabledParam = getValFromTable(motionMonitoringCfg, "enabled");

        _accelDetectMotionParams = mixTables(newDetectMotionParams, _accelDetectMotionParams || {});

        local enable   = !_motionMonitoringEnabled && enabledParam == true;
        local reEnable =  _motionMonitoringEnabled && enabledParam != false && newDetectMotionParams;
        local disable  =  _motionMonitoringEnabled && enabledParam == false;

        if (reEnable || enable) {
            ::debug("(Re)enabling motion monitoring..", "@{CLASS_NAME}");

            _inMotion = false;
            _motionStopAssumption = false;
            _motionMonitoringEnabled = true;

            // Enable (or re-enable) motion detection
            _ad.detectMotion(_onAccelMotionDetected.bindenv(this), _accelDetectMotionParams);
        } else if (disable) {
            ::debug("Disabling motion monitoring..", "@{CLASS_NAME}");

            _inMotion = null;
            _motionStopAssumption = false;
            _motionMonitoringEnabled = false;

            // Disable motion detection
            _ad.detectMotion(null);
            // Cancel the timer for location reading because if we don't detect motion, we don't read location
            // TODO: This will be changed once alwayOn feature is implemented
            _locReadingTimer && imp.cancelwakeup(_locReadingTimer);
        }
    }

    // TODO: Comment
    function _updCfgBLEDevices(cfg) {
        local bleDevicesCfg = getValFromTable(cfg, "locationTracking/bleDevices");
        local enabled = getValFromTable(bleDevicesCfg, "enabled");
        local knownBLEDevices = nullEmpty(getValsFromTable(bleDevicesCfg, ["generic", "iBeacon"]));

        _ld.configureBLEDevices(enabled, knownBLEDevices);
    }

    // TODO: Comment
    function _updCfgGeofence(cfg) {
        local geofenceCfg = getValFromTable(cfg, "locationTracking/geofence");

        // If there is some change, let's reset _inGeofenceZone
        if (geofenceCfg) {
            _inGeofenceZone = null;
        }

        _geofenceEnabled = getValFromTable(geofenceCfg, "enabled", _geofenceEnabled);
        local radius = getValFromTable(geofenceCfg, "radius");

        if (radius != null) {
            _geofenceRadius = radius;
            // If radius is passed, then lat and lng are also passed
            _geofenceCenter = {
                "latitude": geofenceCfg.lat,
                "longitude": geofenceCfg.lng
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
            _motionEventCb && _motionEventCb(false);
        } else {
            // read location and, after that, check if it is the same as the previous one
            _locReading()
            .finally(function(_) {
                if (!_motionMonitoringEnabled) {
                    return;
                }

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
                    _motionEventCb && _motionEventCb(true);
                }
            }
        }

        if (!_curLocFresh && !_prevLocFresh) {
            // the location has not been determined two times in a row,
            // need to double check the motion
            _motionStopAssumption = true;
        }

        if(_motionStopAssumption) {
            // enable motion detection by accelerometer to double check the motion
            _ad.detectMotion(_onAccelMotionDetected.bindenv(this), _accelDetectMotionParams);
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
            _motionEventCb && _motionEventCb(true);

            // TODO: What if _locReadingPeriod is less than the time to get the location?
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
        //              _____GeofenceZone
        //             /      \
        //            /__     R\    dist           __Location
        //           |/\ \  .---|-----------------/- \
        //           |\__/      |                 \_\/accuracy (radius)
        //            \ Location/
        //             \______ /
        //            in zone                     not in zone
        // (location with accuracy radius      (location with accuracy radius
        //  entirely in geofence zone)          entirely not in geofence zone)
        // TODO: location after reboot/reconfigure - not in geofence zone
        if (_geofenceEnabled) {
            local dist = _greatCircleDistance(_geofenceCenter, curLocation);
            ::debug("Geofence distance: " + dist, "@{CLASS_NAME}");
            if (dist > _geofenceRadius) {
                local distWithoutAccurace = dist - curLocation.accuracy;
                if (distWithoutAccurace > 0 && distWithoutAccurace > _geofenceRadius) {
                    if (_inGeofenceZone == null || _inGeofenceZone == true) {
                        _geofencingEventCb && _geofencingEventCb(false);
                        _inGeofenceZone = false;
                    }
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
