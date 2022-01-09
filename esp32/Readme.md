# ESP32 Firmware #

Firmware for the [WiFi BLE click](https://www.mikroe.com/wifi-ble-click) board with ESP32-WROOM-32 module.

## Compile Firmware ##

How to prepare (compile) a firmware is described [here](https://docs.espressif.com/projects/esp-at/en/latest/Compile_and_Develop/).

The latest official firmware version is [2.2.0.0](https://github.com/espressif/esp-at/releases/tag/v2.2.0.0_esp32).

It is already compiled and available [here](https://github.com/espressif/esp-at/files/6767464/ESP32-WROOM_AT_V2.2.0.0.zip).

List of binary files and addresses of their location (in external SPI NOR FLASH):
1) Address: 0x8000, binary image: partition-table.bin 
2) Address: 0x10000, binary image: ota_data_initial.bin 
3) Address: 0xf000, binary image: phy_init_data.bin 
4) Address: 0x1000, binary image: bootloader.bin 
5) Address: 0x100000, binary image: esp-at.bin 
6) Address: 0x20000, binary image: at_customize.bin 
7) Address: 0x21000, binary image: ble_data.bin 
8) Address: 0x24000, binary image: server_cert.bin 
9) Address: 0x26000, binary image: server_key.bin 
10) Address: 0x28000, binary image: server_ca.bin 
11) Address: 0x2a000, binary image: client_cert.bin 
12) Address: 0x2c000, binary image: client_key.bin 
13) Address: 0x2e000, binary image: client_ca.bin 
14) Address: 0x37000, binary image: mqtt_cert.bin 
15) Address: 0x39000, binary image: mqtt_key.bin 
16) Address: 0x3B000, binary image: mqtt_ca.bin 
17) Address: 0x30000, binary image: factory_param.bin

## Flash Firmware ##

The WiFi BLE click board has an internal bootloader accessible through the uart interface (pins: `GND, EN, IO0, RX, TX`) - [schematics](https://download.mikroe.com/documents/add-on-boards/click/wifi-ble/wifi-ble-click-schematic-v102.pdf).

The following is needed for the flashing:
- A usb-uart converter (e.g. FT2232 FTDI).
- A flash utility. For Windows platform - [Flash download tool](https://www.espressif.com/sites/default/files/tools/flash_download_tool_3.9.2.zip).

How to flash a firmware is described [here](https://docs.espressif.com/projects/esp-at/en/latest/Get_Started/Downloading_guide.html).

## Test Firmware ##

A simple Squirrel test which gets a version from ESP32 - [./Esp32Test.device.nut](./Esp32Test.device.nut)

It is setup for the `imp006` module with the WiFi BLE click board connected to the `uartXEFGH` UART port.

Example of the correct log after running the test:
```
2022-01-09T08:55:00.337 +00:00	[Device]	Send request
2022-01-09T08:55:00.578 +00:00	[Device]	AT+GMR
2022-01-09T08:55:00.997 +00:00	[Device]	AT version:2.2.0.0(c6fa6bf - ESP32 - Jul  2 2021 06:44:05)
2022-01-09T08:55:01.315 +00:00	[Device]	SDK version:v4.2.2-76-gefa6eca
2022-01-09T08:55:01.477 +00:00	[Device]	compile time(3a696ba):Jul  2 2021 11:54:43
2022-01-09T08:55:01.578 +00:00	[Device]	Bin version:2.2.0(WROOM-32)
2022-01-09T08:55:01.616 +00:00	[Device]	OK
```
