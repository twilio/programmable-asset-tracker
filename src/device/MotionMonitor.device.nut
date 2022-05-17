@set CLASS_NAME = "MotionMonitor" // Class name for logging

// Mean earth radius in meters (https://en.wikipedia.org/wiki/Great-circle_distance)
const MM_EARTH_RAD = 6371009;

// Motion Monitor class.
// Starts and stops motion monitoring.
class MotionMonitor {
    // Accelerometer driver object
    _ad = null;

    // Location Monitor object
    _lm = null;

    // Motion event callback function
    _motionEventCb = null;

    // Motion stop assumption
    _motionStopAssumption = false;

    // Motion state: true (in motion) / false (not in motion) / null (feature disabled)
    _inMotion = null;

    // Current location
    _curLoc = null;

    // Sign of the current location relevance
    // True (relevant) / false (not relevant) / null (haven't yet got a location or a failure)
    _curLocFresh = null;

    // Previous location
    _prevLoc = null;

    // Sign of the previous location relevance
    // True (relevant) / false (not relevant) / null (haven't yet got a location or a failure)
    _prevLocFresh = null;

    // TODO: Comment
    _motionStopTimeout = null;

    // TODO: Comment
    _confirmMotionStopTimer = null;

    // TODO: Comment
    _motionMonitoringEnabled = false;

    // TODO: Comment
    _accelDetectMotionParams = null;

    /**
     *  Constructor for Motion Monitor class.
     *  @param {object} accelDriver - Accelerometer driver object.
     *  @param {object} locMonitor - Location Monitor object.
     */
    constructor(accelDriver, locMonitor) {
        _ad = accelDriver;
        _lm = locMonitor;
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
        _curLoc = _lm.getStatus().location;
        _prevLoc = clone _curLoc;

        return updateCfg(cfg);
    }

    // TODO: Comment
    function updateCfg(cfg) {
        local detectMotionParamNames = ["movementAccMin", "movementAccMax", "movementAccDur",
                                        "motionTime", "motionVelocity", "motionDistance"];

        local motionMonitoringCfg = getValFromTable(cfg, "locationTracking/motionMonitoring");
        local newDetectMotionParams = nullEmpty(getValsFromTable(motionMonitoringCfg, detectMotionParamNames));
        // Can be: true/false/null
        local enabledParam = getValFromTable(motionMonitoringCfg, "enabled");

        _accelDetectMotionParams = mixTables(newDetectMotionParams, _accelDetectMotionParams || {});
        _motionStopTimeout = getValFromTable(motionMonitoringCfg, "motionStopTimeout", _motionStopTimeout);

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
            // Cancel the timer as we don't check for motion anymore
            _confirmMotionStopTimer && imp.cancelwakeup(_confirmMotionStopTimer);
        }

        return Promise.resolve(null);
    }

    // TODO: Comment
    function getStatus() {
        local res = {
            "flags": {}
        };

        (_inMotion != null) && (res.flags.inMotion <- _inMotion);

        return res;
    }

    /**
     *  Set motion event callback function.
     *  @param {function | null} motionEventCb - The callback will be called every time the new motion event is detected (null - disables the callback)
     *                 motionEventCb(ev), where
     *                 @param {bool} ev - true: motion started, false: motion stopped
     */
    function setMotionEventCb(motionEventCb) {
        _motionEventCb = motionEventCb;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     *  Motion stop confirmation timer callback function
     */
    function _confirmMotionStop() {
        if (_motionStopAssumption) {
            // No movement during motion stop confirmation period => motion stop is confirmed
            _inMotion = false;
            _motionStopAssumption = false;
            _motionEventCb && _motionEventCb(false);

            // Clear these variables so that next time we need to get the location, at least,
            // two times before checking if the motion is stopped
            _curLocFresh = _prevLocFresh = null;
        } else {
            // Since we are still in motion, we need to get new locations
            _lm.setLocationCb(_onLocation.bindenv(this));
        }
    }

    // TODO: Comment
    function _onLocation(location) {
        _prevLoc = _curLoc;
        _prevLocFresh = _curLocFresh;

        if (location) {
            _curLoc = location;
            _curLocFresh = true;
        } else {
            // the current location becomes non-fresh
            _curLocFresh = false;
        }

        // Once we have got two locations or failures, let's check if the motion stopped
        (_prevLocFresh != null) && _checkMotionStop();
    }

    /**
     *  Check if the motion is stopped
     */
    function _checkMotionStop() {
        if (_curLocFresh) {
            // Calculate distance between two locations
            local dist = _lm.greatCircleDistance(_curLoc, _prevLoc);

            ::debug("Distance: " + dist, "@{CLASS_NAME}");

            // Check if the distance is less than 2 radius of accuracy.
            // Maybe motion is stopped but need to double check
            _motionStopAssumption = dist < 2*_curLoc.accuracy;
        } else if (!_prevLocFresh) {
            // The location has not been determined two times in a row,
            // need to double check the motion
            _motionStopAssumption = true;
        }

        if (_motionStopAssumption) {
            // We don't need new locations anymore
            _lm.setLocationCb(null);
            // Enable motion detection by accelerometer to double check the motion
            _ad.detectMotion(_onAccelMotionDetected.bindenv(this), _accelDetectMotionParams);
            // Set a timer for motion stop confirmation timeout
            _confirmMotionStopTimer = imp.wakeup(_motionStopTimeout, _confirmMotionStop.bindenv(this));
        }
    }

    /**
     *  The handler is called when the motion is detected by accelerometer
     */
    function _onAccelMotionDetected() {
        _motionStopAssumption = false;
        if (!_inMotion) {
            _inMotion = true;

            // TODO: Maybe it's better to copy the latest known location to _curLoc here?

            // Start getting new locations to check if we are actually moving
            _lm.setLocationCb(_onLocation.bindenv(this));
            _motionEventCb && _motionEventCb(true);
        }
    }
}

@set CLASS_NAME = null // Reset the variable
