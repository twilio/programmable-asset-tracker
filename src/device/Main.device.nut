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
#require "UBloxM8N.device.lib.nut:1.0.1"
#require "UbxMsgParser.lib.nut:2.0.1"
#require "UBloxAssistNow.device.lib.nut:0.1.0"
#require "BG96_Modem.device.lib.nut:0.0.4"

@include once "../shared/Version.shared.nut"
@include once "../shared/Constants.shared.nut"
@include once "../shared/Logger/Logger.shared.nut"

@if UART_LOGGING || !defined(UART_LOGGING)
@include once "../shared/Logger/stream/UartOutputStream.device.nut"
@endif

@if LED_INDICATION || !defined(LED_INDICATION)
@include once "LedIndication.device.nut"
@endif

@include once "PowerSafeI2C.device.nut"
@include once "FlipFlop.device.nut"
@include once "Hardware.device.nut"
@include once "Helpers.device.nut"
@include once "ProductionManager.device.nut"
@include once "CfgManager.device.nut"
@include once "CustomConnectionManager.device.nut"
@include once "CustomReplayMessenger.device.nut"
@include once "BG9xCellInfo.device.nut"
@include once "ESP32Driver.device.nut"
@include once "Photoresistor.device.nut"
@include once "AccelerometerDriver.device.nut"
@include once "BatteryMonitor.device.nut"
@include once "LocationMonitor.device.nut"
@include once "MotionMonitor.device.nut"
@include once "DataProcessor.device.nut"
@include once "LocationDriver.device.nut"
@include once "SimUpdater.device.nut"

// Main application on Imp-Device: does the main logic of the application

// Connection Manager configuration constants:
// Maximum time allowed for the imp to connect to the server before timing out, in seconds
const APP_CM_CONNECT_TIMEOUT = 180.0;
// Delay before automatic disconnection if there are no connection consumers, in seconds
const APP_CM_AUTO_DISC_DELAY = 10.0;
// Maximum time allowed for the imp to be connected to the server, in seconds
const APP_CM_MAX_CONNECTED_TIME = 180.0;

// Replay Messenger configuration constants:
// The maximum message send rate,
// ie. the maximum number of messages the library allows to be sent in a second
const APP_RM_MSG_SENDING_MAX_RATE = 3;
// The maximum number of messages to queue at any given time when replaying
const APP_RM_MSG_RESEND_LIMIT = 3;

// Send buffer size, in bytes
const APP_SEND_BUFFER_SIZE = 8192;

class Application {
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

@if LED_INDICATION || !defined(LED_INDICATION)
        ledIndication = LedIndication(HW_LED_RED_PIN, HW_LED_GREEN_PIN, HW_LED_BLUE_PIN);
@endif

        // Switch off all flip-flops by default (except the ublox's backup pin)
        local flipFlops = [HW_ESP_POWER_EN_PIN, HW_LDR_POWER_EN_PIN];
        foreach (flipFlop in flipFlops) {
            flipFlop.configure(DIGITAL_OUT, 0);
            flipFlop.disable();
        }

        // Keep the u-blox backup pin always on
        HW_UBLOX_BACKUP_PIN.configure(DIGITAL_OUT, 1);

        _startSystemMonitoring();

        // Create and intialize Replay Messenger
        _initReplayMessenger()
        .then(function(_) {
            HW_ACCEL_I2C.configure(CLOCK_SPEED_400_KHZ);

            // Create and initialize Battery Monitor
            local batteryMon = BatteryMonitor(HW_BAT_LEVEL_POWER_EN_PIN, HW_BAT_LEVEL_PIN);
            // Create and initialize Photoresistor
            local photoresistor = Photoresistor(HW_LDR_POWER_EN_PIN, HW_LDR_PIN);
            // Create and initialize Location Driver
            local locationDriver = LocationDriver();
            // Create and initialize Accelerometer Driver
            local accelDriver = AccelerometerDriver(HW_ACCEL_I2C, HW_ACCEL_INT_PIN);
            // Create and initialize Location Monitor
            local locationMon = LocationMonitor(locationDriver);
            // Create and initialize Motion Monitor
            local motionMon = MotionMonitor(accelDriver, locationMon);
            // Create and initialize Data Processor
            local dataProc = DataProcessor(locationMon, motionMon, accelDriver, batteryMon, photoresistor);
            // Create and initialize SIM Updater
            local simUpdater = SimUpdater();
            // Create and initialize Cfg Manager
            local cfgManager = CfgManager([locationMon, motionMon, dataProc, simUpdater]);
            // Start Cfg Manager
            cfgManager.start();
        }.bindenv(this))
        .fail(function(err) {
            ::error("Error during initialization: " + err);
            pm.enterEmergencyMode("Error during initialization: " + err);
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
     * Start system monitoring (boot time, wake reason, free RAM)
     */
    function _startSystemMonitoring() {
        // Free RAM Checking period (only when the device is connected), in seconds
        const APP_CHECK_FREE_MEM_PERIOD = 2.0;

        local wkup = imp.wakeup.bindenv(imp);
        local getFreeMem = imp.getmemoryfree.bindenv(imp);
        local checkMemTimer = null;

        local bootTime = time();
        local wakeReason = hardware.wakereason();
        local curFreeMem = getFreeMem();
        local minFreeMem = 0x7FFFFFFF;

        local checkFreeMem = function() {
            checkMemTimer && imp.cancelwakeup(checkMemTimer);

            curFreeMem = getFreeMem();
            if (minFreeMem > curFreeMem) {
                minFreeMem = curFreeMem;
            }

            cm.isConnected() && (checkMemTimer = wkup(APP_CHECK_FREE_MEM_PERIOD, callee()));
        }.bindenv(this);

        local onConnected = function() {
            checkFreeMem();
            ::info(format("Boot timestamp %i, wake reason %i, free memory: cur %i bytes, min %i bytes",
                          bootTime,
                          wakeReason,
                          curFreeMem,
                          minFreeMem));
        }.bindenv(this);

        cm.isConnected() && onConnected();
        cm.onConnect(onConnected, "SystemMonitoring");
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

    /**
     * Erase SPI flash
     */
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

// Used to track the shipping of the device. Once the device has been shipped,
// the photoresistor will detect the light
local photoresistor = Photoresistor(HW_LDR_POWER_EN_PIN, HW_LDR_PIN);

// Callback to be called by Production Manager if it allows to run the main application
local startApp = function() {
    // Stop polling as we are going to start the main app => the device has already been shipped.
    // This is guaranteed to be called after (!) the startPolling() call as the startApp callback
    // is called asynchronously (using imp.wakeup)
    photoresistor.stopPolling();
    // Run the application
    ::app <- Application();
};

pm <- ProductionManager(startApp, true);
pm.start();

// If woken by the photoresistor (the wake-up pin was HIGH), the device has been shipped
if (hardware.wakereason() == WAKEREASON_PIN) {
    pm.shipped();
} else {
    local onLightDetected = function(_) {
        photoresistor.stopPolling();
        pm.shipped();
    }.bindenv(this);

    // Start polling to be sure we will not miss light detection while the device is
    // awake (= the wake-up pin is not working for the light detection).
    // Also, this will switch ON (via a flip-flop) the photoresistor and configure the wake-up
    // pin so the light detection is enabled during the deep sleep
    photoresistor.startPolling(onLightDetected);
}
