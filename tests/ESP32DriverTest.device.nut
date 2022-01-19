#require "Promise.lib.nut:4.0.0"

@include once "../src/device/ESP32Driver.device.nut"

// new RX FIFO size
const ESP_DRV_TEST_RX_FIFO_SIZE = 800;

// UART settings
const ESP_DRV_TEST_BAUDRATE = 115200;
const ESP_DRV_TEST_BIT_IN_CHAR = 8;
const ESP_DRV_TEST_STOP_BITS = 1;
const ESP_DRV_TEST_PARITY_NONE = 0;
const ESP_DRV_TEST_NO_CRT_RTS = 4;

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
                   });
// init
esp && esp.init().then(function(initStatus) {
    server.log("Init status: " + initStatus);
    // scan
    esp.scanWiFiNetworks().then(function(result) {
        foreach (ind, val in result) {
            local network = format("%d. ", ind);
            foreach (el in val) {
                switch (el) {
                    case "ssid":
                        network += "SSID: " + el.ssid;
                        break;
                    case ""
                    default:
                        break;
                }
            }
            // server.log();
        }
    }).fail(function(error) {
        server.log("Error: " + error);
    });
}).fail(function(error) {
    server.log("Error: " + error);
});