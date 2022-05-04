@set CLASS_NAME = "LocationMonitor" // Class name for logging

// Mean earth radius in meters (https://en.wikipedia.org/wiki/Great-circle_distance)
const MM_EARTH_RAD = 6371009;

// Motion Monitor class.
// Starts and stops motion monitoring.
class LocationMonitor {
    // Location driver object
    _ld = null;

    // Location callback function
    _locationCb = null;

    // Location reading timer period
    _locReadingPeriod = null;

    // Location reading timer
    _locReadingTimer = null;

    // Promise of the location reading process or null
    _locReadingPromise = null;

    // If true, activate unconditional periodic location reading
    _alwaysReadLocation = false;

    // Geofence settings, state, callback(s), timer(s) and etc.
    _geofence = null;

    // Repossession mode settings, state, callback(s), timer(s) and etc.
    _repossession = null;

    /**
     *  Constructor for Motion Monitor class.
     *  @param {object} locDriver - Location driver object.
     */
    constructor(locDriver) {
        _ld = locDriver;

        // This table will be augmented by several fields from the configuration: "enabled" and "after"
        _repossession = {
            // A flag indicating if the repossession mode is activated
            "activated": false,
            // A timer to activate the repossession mode after the time specified in the configuration
            "timer": null,
            // Repossession event callback function
            "eventCb": null
        };

        // This table will be augmented by several fields from the configuration: "enabled", "lng", "lat" and "radius"
        _geofence = {
            // Geofencing state: true (in zone) / false (out of zone) / null (unknown)
            "inZone": null,
            // Geofencing event callback function
            "eventCb": null
        };
    }

    /**
     *  Start motion monitoring.
     *  @param {table} cfg - Table with the full configuration.
     *                       For details, please, see the documentation
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function start(cfg) {
        updateCfg(cfg);

        // get current location
        _readLocation();

        return Promise.resolve(null);
    }

    // TODO: Comment
    function updateCfg(cfg) {
        _updCfgGeneral(cfg);
        _updCfgBLEDevices(cfg);
        _updCfgGeofence(cfg);
        _updCfgRepossession(cfg);

        return Promise.resolve(null);
    }

    // TODO: Comment
    function getStatus() {
        local location = _ld.lastKnownLocation() || {
            "timestamp": 0,
            "type": "gnss",
            "accuracy": MM_EARTH_RAD,
            "longitude": INIT_LONGITUDE,
            "latitude": INIT_LATITUDE
        };

        local res = {
            "flags": {},
            "location": location
        };

        (_geofence.inZone != null) && (res.flags.inGeofence <- _geofence.inZone);
        _repossession.enabled && (res.flags.repossession <- _repossession.activated);

        return res;
    }

    // TODO: Comment
    function setLocationCb(locationCb) {
        _locationCb = locationCb;
        // This will either:
        // - Run periodic location reading (if a callback has just been set) OR
        // - Cancel the timer for periodic location reading (if the callback has just been
        //   unset and the other conditions don't require to read the location periodically)
        _managePeriodicLocReading(true);
    }

    // TODO Comment
    function setRepossessionEventCb(repossessionEventCb) {
        _repossession.eventCb = repossessionEventCb;
    }

    /**
     *  Set geofencing event callback function.
     *  @param {function | null} geofencingEventCb - The callback will be called every time the new geofencing event is detected (null - disables the callback)
     *                 geofencingEventCb(ev), where
     *                 @param {bool} ev - true: geofence entered, false: geofence exited
     */
    function setGeofencingEventCb(geofencingEventCb) {
        _geofence.eventCb = geofencingEventCb;
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
    function greatCircleDistance(locationFirstPoint, locationSecondPoint) {
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

        return dist;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    // TODO: Comment
    function _updCfgGeneral(cfg) {
        local readingPeriod = getValFromTable(cfg, "locationTracking/locReadingPeriod");
        _alwaysReadLocation = getValFromTable(cfg, "locationTracking/alwaysOn", _alwaysReadLocation);
        _locReadingPeriod = readingPeriod != null ? readingPeriod : _locReadingPeriod;

        // This will either:
        // - Run periodic location reading (if it's not running but the new settings require
        //   this or if the reading period has been changed) OR
        // - Cancel the timer for periodic location reading (if the new settings and the other conditions don't require this) OR
        // - Do nothing (if periodic location reading is already running
        //   (and still should be) and the reading period hasn't been changed)
        _managePeriodicLocReading(readingPeriod != null);
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
        // There can be the following fields: "enabled", "lng", "lat" and "radius"
        local geofenceCfg = getValFromTable(cfg, "locationTracking/geofence");

        // If there is some change, let's reset _geofence.inZone as we now don't know if we are in the zone
        if (geofenceCfg) {
            _geofence.inZone = null;
        }

        _geofence = mixTables(geofenceCfg, _geofence);
    }

    // TODO: Comment
    function _updCfgRepossession(cfg) {
        // There can be the following fields: "enabled" and "after"
        local repossessionCfg = getValFromTable(cfg, "locationTracking/repossessionMode");

        if (repossessionCfg) {
            // repossessionCfg is not null - this means, we have some updates in parameters
            mixTables(repossessionCfg, _repossession);

            // Let's deactivate everything since the settings changed
            _repossession.activated = false;
            _repossession.timer && imp.cancelwakeup(_repossession.timer);

            // And re-activate again if needed
            if (_repossession.enabled) {
                ::debug("Enabling repossession mode..", "@{CLASS_NAME}");

                local activateRepossession = function() {
                    ::debug("Repossession mode activated!", "@{CLASS_NAME}");

                    _repossession.activated = true;
                    _repossession.eventCb && _repossession.eventCb();
                    _readLocation();
                }.bindenv(this);

                // If "after" is less than the current time, this timer will fire immediately
                _repossession.timer = imp.wakeup(_repossession.after - time(), activateRepossession);
            }

            // This will either:
            // - Cancel the timer for periodic location reading (if the new settings and the other conditions don't require this) OR
            // - Do nothing (if periodic location reading is already running and still should be)
            _managePeriodicLocReading();
        }
    }

    // TODO: Comment
    function _managePeriodicLocReading(reset = false) {
        if (_shouldReadPeriodically()) {
            // If the location reading timer is not currently set or if we should "reset" the periodic location reading,
            // let's call _readLocation right now. This will cancel the existing timer (if any) and request the location
            // (if it's not being obtained right now)
            (!_locReadingTimer || reset) && _readLocation();
        } else {
            _locReadingTimer && imp.cancelwakeup(_locReadingTimer);
            _locReadingTimer = null;
        }
    }

    // TODO: Comment
    function _shouldReadPeriodically() {
        return _alwaysReadLocation || _locationCb || _repossession.activated;
    }

    /**
     *  Try to determine the current location
     */
    function _readLocation() {
        if (_locReadingPromise) {
            return;
        }

        local start = hardware.millis();

        _locReadingTimer && imp.cancelwakeup(_locReadingTimer);
        _locReadingTimer = null;

        ::debug("Getting location..", "@{CLASS_NAME}");

        _locReadingPromise = _ld.getLocation()
        .then(function(loc) {
            _locationCb && _locationCb(loc);
            _procGeofence(loc);
        }.bindenv(this), function(_) {
            _locationCb && _locationCb(null);
        }.bindenv(this))
        .finally(function(_) {
            _locReadingPromise = null;

            if (_shouldReadPeriodically()) {
                // Calculate the delay for the timer according to the time spent on location reading
                local delay = _locReadingPeriod - (hardware.millis() - start) / 1000.0;
                ::debug(format("Setting the timer for location reading in %d sec", delay), "@{CLASS_NAME}");
                _locReadingTimer = imp.wakeup(delay, _readLocation.bindenv(this));
            }
        }.bindenv(this));
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
        if (_geofence.enabled) {
            local center = { "latitude": _geofence.lat, "longitude": _geofence.lng };
            local dist = greatCircleDistance(center, curLocation);
            ::debug("Geofence distance: " + dist, "@{CLASS_NAME}");
            if (dist > _geofence.radius) {
                local distWithoutAccurace = dist - curLocation.accuracy;
                if (distWithoutAccurace > 0 && distWithoutAccurace > _geofence.radius) {
                    if (_geofence.inZone != false) {
                        _geofence.eventCb && _geofence.eventCb(false);
                        _geofence.inZone = false;
                    }
                }
            } else {
                local distWithAccurace = dist + curLocation.accuracy;
                if (distWithAccurace <= _geofence.radius) {
                    if (_geofence.inZone != true) {
                        _geofence.eventCb && _geofence.eventCb(true);
                        _geofence.inZone = false;
                    }
                }
            }
        }
    }
}

@set CLASS_NAME = null // Reset the variable
