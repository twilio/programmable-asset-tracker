#require "Promise.lib.nut:4.0.0"
#require "Serializer.class.nut:1.0.0"
#require "SPIFlashLogger.device.lib.nut:2.2.0"
#require "ConnectionManager.lib.nut:3.1.1"
#require "Messenger.lib.nut:0.2.0"
#require "ReplayMessenger.device.lib.nut:0.2.0"
#require "utilities.lib.nut:2.0.0"

@include once "../src/shared/Constants.shared.nut"
@include once "../src/shared/Logger.shared.nut"
@include once "../src/device/CustomReplayMessenger.device.nut"

// Test for sending data to the cloud.
// Main.agent.nut of the application should be used as an agent part of this test.
// The test periodically sends correct and incorrect data to imp-agent,
// that forwards them to the cloud

// Period of sending data to the cloud, in seconds
const TEST_SEND_DATA_PERIOD = 20;

// Replay Messenger configuration constants:
// Allocation for the used SPI Flash Logger
const HW_RM_SFL_START_ADDR = 0x000000;
const HW_RM_SFL_END_ADDR = 0x100000;
// The maximum message send rate,
// ie. the maximum number of messages the library allows to be sent in a second
const APP_RM_MSG_SENDING_MAX_RATE = 5;
// The maximum number of messages to queue at any given time when replaying
const APP_RM_MSG_RESEND_LIMIT = 5;

// Connection Manager connection timeout, in seconds
const APP_CM_CONNECT_TIMEOUT = 300;

/**
 * Create and initialize Replay Messenger
 *
 * @return {Promise} that:
 * - resolves if the operation succeeded
 * - rejects with if the operation failed
 */
function initReplayMessenger() {
    // Configure and initialize SPI Flash Logger
    local sfLogger = SPIFlashLogger(HW_RM_SFL_START_ADDR, HW_RM_SFL_END_ADDR);

    // Configure and create Replay Messenger.
    // Customized Replay Messenger is used.
    local rmConfig = {
        "debug"      : false,
        "maxRate"    : APP_RM_MSG_SENDING_MAX_RATE,
        "resendLimit": APP_RM_MSG_RESEND_LIMIT
    };
    rm = CustomReplayMessenger(sfLogger, rmConfig);

    // Initialize Replay Messenger
    return Promise(function(resolve, reject) {
        rm.init(resolve);
    }.bindenv(this));
}

/**
 * Sends data
 *
 * @param {boolean} correctData - true: send correct data,
 *                                false: send incorrect data
 */
function sendData(correctData) {
    // Hardcoded correct data to send
    local msg = {
        "trackerId": "c0010c2a69f088a4", // imp deviceId
        "timestamp": 1617900077, // Unix time, timestamp when data were read
        "status": {
            "inMotion": true
        },
        "location": {
            "fresh": true, // false - if the latest location has not beed determined, the provided data is the previous location
            "timestamp": 1617900070, // Unix time, timestamp when this location was determined
            "type": "gnss", // Possible values: "gnss", "cell", "wifi", "ble"
            "accuracy": 3, // in meters
            "lng": 30.571465,
            "lat": 59.749069
        },
        "sensors": {
            "batteryLevel": 64.32, // in %
            "temperature": 42.191177 // in Celsius
        },
        "alerts": [ // optional. Array of strings. Possible values: "temperatureHigh", "temperatureLow", "batteryLow", "shockDetected", "motionStarted", "motionStopped", "geofenceEntered", "geofenceExited"
            "temperatureHigh",
            "shockDetected"
        ]
    }

    if (correctData) {
        // Send correct data
        rm.send(APP_RM_MSG_NAME.DATA, msg);
    } else {
        // Send incorrect (empty) data
        rm.send(APP_RM_MSG_NAME.DATA, "\x00");
    }

    // Periodically repeat sending of correct/incorrect data
    imp.wakeup(TEST_SEND_DATA_PERIOD, function() {
        sendData(!correctData);
    }.bindenv(this));
}

// ---------------------------- THE MAIN CODE ---------------------------- //

// Connection Manager, controls connection with Imp-Agent
cm <- null;

// Replay Messenger, communicates with Imp-Agent
rm <- null;

// Location Monitor, obtains the current location
lm <- null;

// Create and initialize Connection Manager
// NOTE: This needs to be called as early in the code as possible
// in order to run the application without a connection to the Internet
// (it sets the appropriate send timeout policy)
cmConfig <- {
        "stayConnected"   : true,
        "errorPolicy"     : RETURN_ON_ERROR_NO_DISCONNECT,
        "connectTimeout"  : APP_CM_CONNECT_TIMEOUT
};
cm = ConnectionManager(cmConfig);
cm.connect();

Logger.setLogLevel(LGR_LOG_LEVEL.DEBUG);
::info("Test sending data to the cloud started");

// Create and initialize Replay Messenger
initReplayMessenger()
.then(function(_) {
    // Periodically send data
    sendData(true);
}.bindenv(this), function(err) {
    ::error("Replay Messenger initialization error: " + err);
}.bindenv(this));
