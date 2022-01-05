# The esp-at software #

**The esp-at software downloading to the wifi-ble-click board**

The esp-at software is loaded onto the wifi-ble-click board using the utility [Flash download tool](https://www.espressif.com/sites/default/files/tools/flash_download_tool_3.9.2.zip) (platform - Windows PC).

The wifi-ble-click board has an internal bootloader accessible through the uart interface (pins: GND, EN, IO0, RX, TX). The [schematic](https://download.mikroe.com/documents/add-on-boards/click/wifi-ble/wifi-ble-click-schematic-v102.pdf).

For flashing software, you need a usb-uart converter (e.g. FT2232 FTDI).
The esp-at software version 2.3.0.0 is [used](https://github.com/espressif/esp-at.git).
The software build sequence is described in [compile and download chapter](https://docs.espressif.com/projects/esp-at/en/latest/Compile_and_Develop/How_to_clone_project_and_compile_it).
The software dowload sequence is described in [downloading guide chapter](https://docs.espressif.com/projects/esp-at/en/latest/Get_Started/Downloading_guide.html).

**The fw directory**

The fw directory contains necessary binary files. List of files and addresses of their location (in external SPI NOR FLASH):
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

**Test script**

The correct operation of the wifi-ble-click board after loading the software is checked using a test script Esp32Test.device.nut (the software version, SDK version requested). Board: imp006. Uart: uartXEFGH. Uart settings: 115200 baud, 8N1. Upon successful software update, the following response is returned:
```
2022-01-05 00:36:30+0400 [Device] AT+GMR
2022-01-05 00:36:33+0400 [Device] AT version:2.3.0.0-dev(e98993f - ESP32 - Dec 23 2021 09:03:31)
2022-01-05 00:36:35+0400 [Device] SDK version:v4.2.2-331-g5595042-dirty
2022-01-05 00:36:39+0400 [Device] compile time(9ff133D):Dec 30 2021  
2022-01-05 00:36:41+0400 [Device] Bin version:2.3.0(WROOM-32)
2022-01-05 00:36:44+0400 [Device] OK
```