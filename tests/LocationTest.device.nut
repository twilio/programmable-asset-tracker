#require "Promise.lib.nut:4.0.0"
#require "Serializer.class.nut:1.0.0"
#require "SPIFlashLogger.device.lib.nut:2.2.0"
#require "ConnectionManager.lib.nut:3.1.1"
#require "Messenger.lib.nut:0.2.0"
#require "ReplayMessenger.device.lib.nut:0.2.0"
#require "utilities.lib.nut:2.0.0"

@include once "../src/shared/Constants.shared.nut"
@include once "../src/shared/Logger/Logger.shared.nut"
@include once "../src/device/Hardware.device.nut"
@include once "../src/device/CustomConnectionManager.device.nut"
@include once "../src/device/CustomReplayMessenger.device.nut"
@include once "../src/device/bg96_gps.device.lib.nut"
@include once "../src/device/BG96CellInfo.device.nut"
@include once "../src/device/ESP32Driver.device.nut"

@if BG96_GNSS
@include once "../src/device/LocationDriverBG96.device.nut"
@else
@include once "../src/device/LocationDriver.device.nut"
@endif


// Test for Location determination.
// Periodically tries to obtain the current location by different ways.
// Imp-Device part - tests/uses LocationDriver:
//   - tries to obtain location using GNSS
//   - tries to obtain location using cellular info
//   - tries to obtain location using WiFi info
//   - tries to obtain location using BLE beacons
//   - logs the obtained locations

// Period to repeat location obtaining, in seconds
const TEST_GET_LOCATION_PERIOD = 600;

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
 * Create and intialize Replay Messenger
 *
 * @return {Promise} that:
 * - resolves if the operation succeeded
 * - rejects with if the operation failed
 */
function initReplayMessenger() {
    // Configure and intialize SPI Flash Logger
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

function printResult(loc) {
    foreach (key, value in loc) {
        ::info(key + ":" + value);
    }
}

/**
 * Obtains location
 */
 function getLocation() {

     // Obtain and log location by BLE beacons
    ld._getLocationBLEBeacons()
    .then(function(loc){
        ::info("Location BLE beacons:");
        printResult(loc);
    })
    .finally(function(_) {
        // Obtain and log location by GNSS
        ld._getLocationGNSS()
        .then(function(loc){
            ::info("Location GNSS:");
            printResult(loc);
        })
        .finally(function(_) {
            // Obtain and log location by cell info and WiFi
            ld._getLocationCellTowersAndWiFi()
            .then(function(loc){
                ::info("Location cell tower and wifi:");
                printResult(loc);
            });
        });
    });

    // Periodically repeat
    imp.wakeup(TEST_GET_LOCATION_PERIOD, getLocation);
}

// ---------------------------- THE MAIN CODE ---------------------------- //

// Connection Manager, controls connection with Imp-Agent
cm <- null;

// Replay Messenger, communicates with Imp-Agent
rm <- null;

// Location Driver, obtains the current location
ld <- null;

// Create and intialize Connection Manager
// NOTE: This needs to be called as early in the code as possible
// in order to run the application without a connection to the Internet
// (it sets the appropriate send timeout policy)
cmConfig <- {
        "stayConnected"   : true,
        "errorPolicy"     : RETURN_ON_ERROR_NO_DISCONNECT,
        "connectTimeout"  : APP_CM_CONNECT_TIMEOUT
};
cm = CustomConnectionManager(cmConfig);
cm.connect();

Logger.setLogLevel(LGR_LOG_LEVEL.DEBUG);
::info("Location test started");

// Create and intialize Replay Messenger
initReplayMessenger()
.then(function(_) {
    // Create and initialize Location Driver
    ld = LocationDriver();

    // Start periodic obtaining of the current location
    getLocation();

}.bindenv(this), function(err) {
    ::error("Replay Messenger initialization error: " + err);
}.bindenv(this));
