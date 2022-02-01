#require "Promise.lib.nut:4.0.0"

@include once "../src/shared/Logger/Logger.shared.nut"
@include once "../src/device/ESP32Driver.device.nut"

// new RX FIFO size
const ESP_DRV_TEST_RX_FIFO_SIZE = 800;

// UART settings
const ESP_DRV_TEST_BAUDRATE = 115200;
const ESP_DRV_TEST_BIT_IN_CHAR = 8;
const ESP_DRV_TEST_STOP_BITS = 1;
const ESP_DRV_TEST_PARITY_NONE = 0;
const ESP_DRV_TEST_NO_CRT_RTS = 4;

// scan WiFi period, in seconds
const ESP_DRV_TEST_SCAN_WIFI_PERIOD = 60;

server.log("ESP AT test");

function scan() {
    esp.scanWiFiNetworks().then(function(wifiNetworks) {
        server.log("Find "  + wifiNetworks.len() + " WiFi network:");
        foreach (ind, network in wifiNetworks) {
            local networkStr = format("%d) ", ind + 1);
            foreach (el, val in network) {
                networkStr += el + ": " + val + ", "
            }
            local networkStrLen = networkStr.len();
            // remove ", "
            server.log(networkStr.slice(0, networkStrLen - 2));
        }
    }).fail(function(error) {
        server.log("Scan WiFi network error: " + error);
    }).finally(function(_) {
        imp.wakeup(ESP_DRV_TEST_SCAN_WIFI_PERIOD, scan);
    });
}

Logger.setLogLevel(LGR_LOG_LEVEL.DEBUG);

// create ESP32 driver object
esp <- ESP32Driver(hardware.pinXU,
                   hardware.uartXEFGH,
                   {
                        "baudRate"  : ESP_DRV_TEST_BAUDRATE,
                        "wordSize"  : ESP_DRV_TEST_BIT_IN_CHAR,
                        "parity"    : ESP_DRV_TEST_PARITY_NONE,
                        "stopBits"  : ESP_DRV_TEST_STOP_BITS,
                        "flags"     : ESP_DRV_TEST_NO_CRT_RTS,
                        "rxFifoSize": ESP_DRV_TEST_RX_FIFO_SIZE
                   }
                );
server.log("ESP32 chip boot...");
// esp chip boot delay
server.log("init...");
// init and start scan
scan();
