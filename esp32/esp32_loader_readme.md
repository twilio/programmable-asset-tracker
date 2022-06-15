# ESP32 Loader Example #

This software is designed to interact with the [UART ROM loader](https://docs.espressif.com/projects/esptool/en/latest/esp32c3/advanced-topics/serial-protocol.html) in order to change the firmware of the ESP32/ESP32C3 MCU.

Software files are downloaded using REST API (PUT requests) on imp-agent.
List of REST API endpoints for ESP-AT software packet (PUT /esp32-xxx (where xxx - specific .bin firmware file):
1)  /esp32-partition-table
2)  /esp32-ota_data_initial
3)  /esp32-phy_init_data 
4)  /esp32-bootloader
5)  /esp32-esp-at
6)  /esp32-at_customizeta
7)  /esp32-ble_data
8)  /esp32-server_cert
9)  /esp32-server_key
10) /esp32-server_ca
11) /esp32-client_cert
12) /esp32-client_key
13) /esp32-client_ca
14) /esp32-mqtt_cert
15) /esp32-mqtt_key
16) /esp32-mqtt_ca
17) /esp32-factory_param
18) /esp32-reboot 
Endpoint `/esp32-reboot` is using for the start downloaded firmware after writing all files to the flash.
The integrity of uploaded files is checked using the MD5 algorithm (HTTP "Content-MD5" header). No authentication required. It is possible to transfer only one firmware file at a time.
The list of endpoints is set using APP_REST_API_DATA_ENDPOINTS table in imp-agent source code (format: {"file": ESP flash address}).

## ESP ROM loader UART ##

Imp-device UART connected to the ESP ROM loader UART is set using APP_ESP_UART global variable.

## ESP ROM loader strap pins ##

The transition to the loading mode is carried out by actions on the strapping pins.
Imp-device pins connected to the ESP loader strap pins are set using APP_STRAP_PIN1, APP_STRAP_PIN2, APP_STRAP_PIN3 global variables.
ESP strap pins are described to the [ESP32WROOM32, ESP32C3 MCU datasheets](https://www.espressif.com/en/support/documents/technical-documents).

## ESP ROM loader power enable pin ##

ESP power enable pin is set using APP_SWITCH_PIN global variable.
