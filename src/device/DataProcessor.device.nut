@set CLASS_NAME = "DataProcessor" // Class name for logging

// Data Processor class.
// 
class DataProcessor {

    /**
     *  Constructor for Data Processor class.
     *  @param {object} motionMon - Motion monitor object.
     *  @param {object} accelDriver - Accelerometer driver object.
     */
    constructor(motionMon, accelDriver) {
        
    }

    /**
     *  Start data processing.
     *   @param {table} dataProcSettings - Table with the settings.
     *        Optional, all settings have defaults.
     *        The settings:
     *          "": {} - Default:
     */
    function start(dataProcSettings = {}) {

    }

    /**
     *  The handler is called when a new temperature value is received.
     *  @param {integer} temperVal - Temperature value.
     */
    function onNewTemperValue(temperVal) {
        
    }

    /**
     *  The handler is called when a new location is received.
     *  @param {table} loc - New location table.
     *      The fields:
     *          "timestamp": {integer}  - Time value
     *               "type": {string}   - gnss or cell e.g.
     *           "accuracy": {}         - Accuracy in meters
     *          "longitude": {}         - Longitude in degrees
     *           "latitude": {}         - Latitude in degrees
     */
    function onNewLocation(loc) {

    }

    /**
     *  The handler is called when a new battery level is received.
     *  @param {integer} lev - Сharge level in percent.
     */
    function onNewBatteryLevel(lev) {

    }

    /**
     * The handler is called when a new shock event is detected.
     */
    function onShockDetectedEvent() {

    }

    /**
     *  The handler is called when a new motion event is detected.
     *  @param {bool} eventType - If true - in motion.
     */
    function onMotionEvent(eventType) {
        
    }

    /**
     *  The handler is called when a new motion event is detected.
     *  @param {bool} eventType - If true - geofence entered.
     */
    function onGeofencingEvent(eventType) {
        
    }

    /**
     *  Set data saving callback function.
     *  @param {function} cb - The callback will be called every time the data is ready to be saved.
     */
    function setDataSavingCb(cb) {

    }

    /**
     *  Set data sending callback function.
     *  @param {function} cb - The callback will be called every time the data is ready to be sent.
     */
    function setDataSendingCb(cb) {

    }
}

@set CLASS_NAME = null // Reset the variable