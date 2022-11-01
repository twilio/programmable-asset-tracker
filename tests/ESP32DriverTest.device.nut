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

function scanWiFi() {
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
        imp.wakeup(ESP_DRV_TEST_SCAN_WIFI_PERIOD, scanBeacons);
    });
}

function scanBeacons() {
    esp.scanBLEBeacons().then(function(beacons) {
        server.log(" Beacons:");
        foreach (ind, beacon in beacons) {
            server.log("Beacon address: " + beacon["addr"]);
        }
    }).fail(function(error) {
        server.log("Scan BLE beacons error: " + error);
    }).finally(function(_) {
        imp.wakeup(0, scanWiFi);
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
scanBeacons();
