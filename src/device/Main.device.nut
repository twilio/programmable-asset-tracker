#require "Serializer.class.nut:1.0.0"
#require "JSONParser.class.nut:1.0.1"
#require "JSONEncoder.class.nut:2.0.0"
#require "Promise.lib.nut:4.0.0"
#require "SPIFlashLogger.device.lib.nut:2.2.0"
#require "SPIFlashFileSystem.device.lib.nut:3.0.1"
#require "ConnectionManager.lib.nut:3.1.1"
#require "Messenger.lib.nut:0.2.0"
#require "ReplayMessenger.device.lib.nut:0.2.0"
#require "utilities.lib.nut:3.0.1"
#require "LIS3DH.device.lib.nut:3.0.0"
#require "HTS221.device.lib.nut:2.0.2"
#require "UBloxM8N.device.lib.nut:1.0.1"
#require "UbxMsgParser.lib.nut:2.0.1"
#require "UBloxAssistNow.device.lib.nut:0.1.0"

@if MAX17055 || !defined(MAX17055)
#require "MAX17055.device.lib.nut:1.0.2"
@endif

// TODO: Aggregate all constants that should be customized in production in one place?

@include once "../shared/Version.shared.nut"
@include once "../shared/Constants.shared.nut"
@include once "../shared/Logger/Logger.shared.nut"

@if UART_LOGGING || !defined(UART_LOGGING)
@include once "../shared/Logger/stream/UartOutputStream.device.nut"
@endif

@if LED_INDICATION || !defined(LED_INDICATION)
@include once "LedIndication.device.nut"
@endif

@include once "Hardware.device.nut"
@include once "Helpers.device.nut"
@include once "ProductionManager.device.nut"
@include once "CfgManager.device.nut"
@include once "CustomConnectionManager.device.nut"
@include once "CustomReplayMessenger.device.nut"
@include once "BG96CellInfo.device.nut"
@include once "ESP32Driver.device.nut"
@include once "AccelerometerDriver.device.nut"
@include once "BatteryMonitor.device.nut"
@include once "LocationMonitor.device.nut"
@include once "MotionMonitor.device.nut"
@include once "DataProcessor.device.nut"
@include once "LocationDriver.device.nut"

// Main application on Imp-Device: does the main logic of the application

// Connection Manager configuration constants:
// Maximum time allowed for the imp to connect to the server before timing out, in seconds
const APP_CM_CONNECT_TIMEOUT = 180.0;
// Delay before automatic disconnection if there are no connection consumers, in seconds
const APP_CM_AUTO_DISC_DELAY = 10.0;
// Maximum time allowed for the imp to be connected to the server, in seconds
const APP_CM_MAX_CONNECTED_TIME = 300.0;

// Replay Messenger configuration constants:
// The maximum message send rate,
// ie. the maximum number of messages the library allows to be sent in a second
const APP_RM_MSG_SENDING_MAX_RATE = 5;
// The maximum number of messages to queue at any given time when replaying
const APP_RM_MSG_RESEND_LIMIT = 5;

// Send buffer size, in bytes
const APP_SEND_BUFFER_SIZE = 10240;

// TODO: Check the RAM consumption!
class Application {
    _locationDriver = null;
    _accelDriver = null;
    _cfgManager = null;
    _batteryMon = null;
    _locationMon = null;
    _motionMon = null;
    _dataProc = null;
    _thermoSensDriver = null;

    /**
     * Application Constructor
     */
    constructor() {
@if ERASE_MEMORY
        pm.isNewDeployment() && _eraseFlash();
@endif

        // Create and intialize Connection Manager
        // NOTE: This needs to be called as early in the code as possible
        // in order to run the application without a connection to the Internet
        // (it sets the appropriate send timeout policy)
        _initConnectionManager();

@if UART_LOGGING || !defined(UART_LOGGING)
        local outStream = UartOutputStream(HW_LOGGING_UART);
        Logger.setOutputStream(outStream);
@endif

        ::info("Application Version: " + APP_VERSION);
        ::debug("Wake reason: " + hardware.wakereason());

@if LED_INDICATION || !defined(LED_INDICATION)
        ledIndication = LedIndication(HW_LED_RED_PIN, HW_LED_GREEN_PIN, HW_LED_BLUE_PIN);
@endif

        // Create and intialize Replay Messenger
        _initReplayMessenger()
        .then(function(_) {
            HW_SHARED_I2C.configure(CLOCK_SPEED_400_KHZ);

            _batteryMon = BatteryMonitor(HW_SHARED_I2C);
            return _batteryMon.init();
        }.bindenv(this))
        .then(function(_) {
            // Create and initialize Location Driver
            _locationDriver = LocationDriver();

            // Create and initialize Accelerometer Driver
            _accelDriver = AccelerometerDriver(HW_SHARED_I2C, HW_ACCEL_INT_PIN);

            // Create and initialize Thermosensor Driver
            _thermoSensDriver = HTS221(HW_SHARED_I2C);
            _thermoSensDriver.setMode(HTS221_MODE.ONE_SHOT);

            // Create and initialize Location Monitor
            _locationMon = LocationMonitor(_locationDriver);
            // Create and initialize Motion Monitor
            _motionMon = MotionMonitor(_accelDriver, _locationMon);
            // Create and initialize Data Processor
            _dataProc = DataProcessor(_locationMon, _motionMon, _accelDriver, _thermoSensDriver, _batteryMon);
            // Create and initialize Cfg Manager
            _cfgManager = CfgManager([_locationMon, _motionMon, _dataProc]);
            // Start Cfg Manager
            _cfgManager.start();
        }.bindenv(this))
        .fail(function(err) {
            ::error("Error during initialization: " + err);

            // TODO: Reboot after a delay? Or enter the emergency mode?
        }.bindenv(this));
    }

    // -------------------- PRIVATE METHODS -------------------- //

     /**
     * Create and intialize Connection Manager
     */
    function _initConnectionManager() {
        imp.setsendbuffersize(APP_SEND_BUFFER_SIZE);

        // Customized Connection Manager is used
        local cmConfig = {
@if LED_INDICATION || !defined(LED_INDICATION)
            "blinkupBehavior"    : CM_BLINK_ON_CONNECT,
@else
            "blinkupBehavior"    : CM_BLINK_NEVER,
@endif
            "errorPolicy"        : RETURN_ON_ERROR_NO_DISCONNECT,
            "connectTimeout"     : APP_CM_CONNECT_TIMEOUT,
            "autoDisconnectDelay": APP_CM_AUTO_DISC_DELAY,
            "maxConnectedTime"   : APP_CM_MAX_CONNECTED_TIME
        };
        cm = CustomConnectionManager(cmConfig);
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
        rm.confirmResend(_confirmResend.bindenv(this));

        return Promise(function(resolve, reject) {
            rm.init(resolve);
        }.bindenv(this));
    }

    /**
     * A handler used by Replay Messenger to decide if a message should be re-sent
     *
     * @param {Message} message - The message (an instance of class Message) being replayed
     *
     * @return {boolean} - `true` to confirm message resending or `false` to drop the message
     */
    function _confirmResend(message) {
        // Resend all messages with the specified names
        local name = message.payload.name;
        return name == APP_RM_MSG_NAME.DATA;
    }

    // TODO: Comment
    function _eraseFlash() {
        ::info(format("Erasing SPI flash from 0x%x to 0x%x...", HW_ERASE_FLASH_START_ADDR, HW_ERASE_FLASH_END_ADDR));

        local spiflash = hardware.spiflash;
        spiflash.enable();

        for (local addr = HW_ERASE_FLASH_START_ADDR; addr < HW_ERASE_FLASH_END_ADDR; addr += 0x1000) {
            spiflash.erasesector(addr);
        }

        spiflash.disable();
        ::info("Erasing finished!");
    }
}

// ---------------------------- THE MAIN CODE ---------------------------- //

// Connection Manager, controls connection with Imp-Agent
cm <- null;

// Replay Messenger, communicates with Imp-Agent
rm <- null;

// LED indication
ledIndication <- null;

// Callback to be called by Production Manager if it allows to run the main application
function startApp() {
    // Run the application
    ::app <- Application();
}

pm <- ProductionManager(startApp);
pm.start();