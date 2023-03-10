// MIT License

// Copyright (C) 2022, Twilio, Inc. <help@twilio.com>

// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do
// so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#require "Promise.lib.nut:4.0.0"
#require "Serializer.class.nut:1.0.0"
#require "SPIFlashLogger.device.lib.nut:2.2.0"
#require "SPIFlashFileSystem.device.lib.nut:3.0.1"
#require "ConnectionManager.lib.nut:3.1.1"
#require "Messenger.lib.nut:0.2.0"
#require "ReplayMessenger.device.lib.nut:0.2.0"
#require "utilities.lib.nut:3.0.1"
#require "UBloxM8N.device.lib.nut:1.0.1"
#require "UbxMsgParser.lib.nut:2.0.1"
#require "UBloxAssistNow.device.lib.nut:0.1.0"

@include once "../src/shared/Constants.shared.nut"
@include once "../src/shared/Logger/Logger.shared.nut"
@include once "../src/device/Hardware.device.nut"
@include once "../src/device/CustomConnectionManager.device.nut"
@include once "../src/device/CustomReplayMessenger.device.nut"
@include once "../src/device/BG9xCellInfo.device.nut"
@include once "../src/device/ESP32Driver.device.nut"
@include once "../src/device/Configuration.device.nut"
@include once "../src/device/LocationDriver.device.nut"


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
 * Obtains location Cell Towers and WiFi
 */
 function testGetLocationCellTowersAndWiFi() {

     // Obtain and log location by cell info and WiFi
    ld._getLocationCellTowersAndWiFi()
    .then(function(loc){
        ::info("Location cell tower and wifi:");
        printResult(loc);
        imp.wakeup(TEST_GET_LOCATION_PERIOD, testGetLocationBLE);
    })
    .fail(function(err){
        ::info("Location cell tower and wifi error: " + err);
        imp.wakeup(TEST_GET_LOCATION_PERIOD, testGetLocationBLE);
    });
}

/**
 * Obtains location GNSS
 */
 function testGetLocationGNSS() {

     // Obtain and log location by GNSS
    ld._getLocationGNSS()
    .then(function(loc){
        ::info("Location GNSS:");
        printResult(loc);
        imp.wakeup(0, testGetLocationCellTowersAndWiFi);
    })
    .fail(function(err){
        ::info("Location GNSS error: " + err);
        imp.wakeup(0, testGetLocationCellTowersAndWiFi);
    });
}

/**
 * Obtains location BLE beacons
 */
 function testGetLocationBLE() {

     // Obtain and log location by BLE device
    ld._getLocationBLEDevices()
    .then(function(loc){
        ::info("Location BLE device:");
        printResult(loc);
        imp.wakeup(0, testGetLocationGNSS);
    })
    .fail(function(err){
        ::info("Location BLE device error: " + err);
        imp.wakeup(0, testGetLocationGNSS);
    });
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
    testGetLocationBLE();

}.bindenv(this), function(err) {
    ::error("Replay Messenger initialization error: " + err);
}.bindenv(this));
