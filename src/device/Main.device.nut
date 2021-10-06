#require "Serializer.class.nut:1.0.0"
#require "Promise.lib.nut:4.0.0"
#require "SPIFlashLogger.device.lib.nut:2.2.0"
#require "ConnectionManager.lib.nut:3.1.1"
#require "Messenger.lib.nut:0.2.0"
#require "ReplayMessenger.device.lib.nut:0.2.0"
#require "utilities.lib.nut:2.0.0"
#require "LIS3DH.device.lib.nut:3.0.0"
#require "HTS221.device.lib.nut:2.0.2"

@include once "../shared/Version.shared.nut"
@include once "../shared/Constants.shared.nut"
@include once "../shared/Logger.shared.nut"
@include once "Configuration.device.nut"
@include once "CustomReplayMessenger.device.nut"
@include once "bg96_gps.device.lib.nut"
@include once "BG96CellInfo.device.nut"
@include once "LocationDriver.device.nut"
@include once "AccelerometerDriver.device.nut"
@include once "MotionMonitor.device.nut"
@include once "DataProcessor.device.nut"

// Main application on Imp-Device: does the main logic of the application

// Connection Manager configuration constants
// Maximum time allowed for the imp to connect to the server before timing out, in seconds
const APP_CM_CONNECT_TIMEOUT = 180.0;

// Replay Messenger configuration constants:
// Allocation for the used SPI Flash Logger
const HW_RM_SFL_START_ADDR = 0x000000;
const HW_RM_SFL_END_ADDR = 0x100000;
// The maximum message send rate,
// ie. the maximum number of messages the library allows to be sent in a second
const APP_RM_MSG_SENDING_MAX_RATE = 5;
// The maximum number of messages to queue at any given time when replaying
const APP_RM_MSG_RESEND_LIMIT = 5;

class Application {
    _locationDriver = null;
    _accelDriver = null;
    _motionMon = null;
    _dataProc = null;
    _thermoSensDriver = null;
    
    /**
     * Application Constructor
     */
    constructor() {
        // Create and intialize Connection Manager
        // NOTE: This needs to be called as early in the code as possible
        // in order to run the application without a connection to the Internet
        // (it sets the appropriate send timeout policy)
        _initConnectionManager();

        ::info("Application Version: " + APP_VERSION);
        ::debug("Wake reason: " + hardware.wakereason());

        imp.onunhandledexception(function(error) {
            ::error("Globally caught error: " + error);
        }.bindenv(this));

        // Create and intialize Replay Messenger
        _initReplayMessenger()
        .then(function(_) {
            // Create and initialize Location Driver
            _locationDriver = LocationDriver();

            // Create and initialize Accelerometer Driver
            _accelDriver = AccelerometerDriver(hardware.i2cLM, hardware.pinW);

            // Create and initialize Thermosensor Driver
            _thermoSensDriver = HTS221(hardware.i2cLM);
            _thermoSensDriver.setMode(HTS221_MODE.ONE_SHOT);

            // Create and initialize Motion Monitor
            _motionMon = MotionMonitor(_accelDriver, _locationDriver);

            // Create and initialize Data Processor
            _dataProc = DataProcessor(_motionMon, _accelDriver, _thermoSensDriver, null);

            // Start other activities - TODO

        }.bindenv(this), function(err) {
            ::error("Replay Messenger initialization error: " + err);
        }.bindenv(this));
    }

    // -------------------- PRIVATE METHODS -------------------- //

     /**
     * Create and intialize Connection Manager
     */
    function _initConnectionManager() {
        local cmConfig = {
            "blinkupBehavior" : CM_BLINK_NEVER,
            "errorPolicy"     : RETURN_ON_ERROR_NO_DISCONNECT,
            "connectTimeout"  : APP_CM_CONNECT_TIMEOUT
        };
        cm = ConnectionManager(cmConfig);
        cm.onConnect(_onConnect.bindenv(this), "main");
        cm.onTimeout(_onConnectionTimeout.bindenv(this), "main");
        cm.onDisconnect(_onDisconnect.bindenv(this), "main");
        cm.connect();
    }

    /**
     * Create and intialize Replay Messenger
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects with if the operation failed
     */
    function _initReplayMessenger() {
        // Configure and intialize SPI Flash Logger
        local sfLogger = SPIFlashLogger(HW_RM_SFL_START_ADDR, HW_RM_SFL_END_ADDR);

        // Configure and intialize Replay Messenger.
        // Customized Replay Messenger is used.
        local rmConfig = {
            "debug"      : false,
            "maxRate"    : APP_RM_MSG_SENDING_MAX_RATE,
            "resendLimit": APP_RM_MSG_RESEND_LIMIT
        };
        rm = CustomReplayMessenger(sfLogger, rmConfig);

        return Promise(function(resolve, reject) {
            rm.init(resolve);
        }.bindenv(this));
    }

    /**
     * Handler called when the device becomes connected
     */
    function _onConnect() {
        ::info("Connected");
    }

    /**
     * Handler called when a connection try is timed out
     */
    function _onConnectionTimeout() {
        ::debug("Connection timeout");
    }

    /**
     * Handler called when the device becomes disconnected
     */
    function _onDisconnect(expected) {
        ::debug("Disconnected");
    }
}

// ---------------------------- THE MAIN CODE ---------------------------- //

// Connection Manager, controls connection with Imp-Agent
cm <- null;

// Replay Messenger, communicates with Imp-Agent
rm <- null;

// Set default log level
Logger.setLogLevel(LGR_LOG_LEVEL.@{DEFAULT_LOG_LEVEL ? DEFAULT_LOG_LEVEL : "INFO"});

// Run the application
app <- Application();
