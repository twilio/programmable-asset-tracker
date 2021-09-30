@set CLASS_NAME = "MotionMonitor" // Class name for logging

// Motion Monitor class.
// 
class MotionMonitor {

    // Accelerometer driver object
    _ad = null;

    // Location driver object
    _ld = null;

    /**
     *  Constructor for Motion Monitor class.
     *  @param {object} accelDriver - Accelerometer driver object.
     *  @param {object} locDriver - Location driver object.
     */
    constructor(accelDriver, locDriver) {
        
    }

    /**
     *   Start motion monitoring.
     *   @param {table} motionMonSettings - Table with the settings.
     *        Optional, all settings have defaults.
     *        The settings:
     *          "": {} - Default:  
     */
    function start(motionMonSettings = {}) {

    }

    /**
     *   Stop motion monitoring.     
     */
    function stop() {

    }

    /**
     *  Set new location callback function.
     *  @param {function} cb - The callback will be called every time the new location is received.
     */
    function setNewLocationCb(cb) {

    }

    /**
     *  Set motion event callback function.
     *  @param {function} cb - The callback will be called every time the new motion event is detected.
     */
    function setMotionEventCb(cb) {
        
    }

    /**
     *  Set geofencing event callback function.
     *  @param {function} cb - The callback will be called every time the new geofencing event is detected.
     */
    function setGeofencingEventCb(cb) {

    }
}

@set CLASS_NAME = null // Reset the variable