# ESP32 Firmware #

How to flash/reflash ESP-AT firmware for the [esp32-c3fn4 chip (ESP32-C3 Series)](https://www.espressif.com/sites/default/files/documentation/esp32-c3_datasheet_en.pdf) used in the Prog-X Asset Tracker module.

## Check Current Firmware ##

A simple Squirrel test which gets a version from ESP32 - [./Esp32Test.device.nut](./Esp32Test.device.nut)

Example of the correct log after running the test:
```
2022-07-07T14:14:17.048 +00:00 	[Device] 	Send request
2022-07-07T14:14:17.847 +00:00 	[Device] 	AT+GMR
2022-07-07T14:14:17.847 +00:00 	[Device] 	AT version:2.4.0.0(4c6eb5e - ESP32C3 - May 20 2022 03:11:59)
2022-07-07T14:14:17.847 +00:00 	[Device] 	SDK version:qa-test-v4.3.3-20220423
2022-07-07T14:14:17.847 +00:00 	[Device] 	compile time(5641e0a):May 20 2022 11:13:44
2022-07-07T14:14:17.847 +00:00 	[Device] 	Bin version:2.4.0(MINI-1)
2022-07-07T14:14:17.847 +00:00 	[Device] 	OK
```

If ESP32 chip has no firmware:
```
2022-07-01 02:43:31+0400 [Device] Send request
2022-07-01 02:44:31+0400 [Device] Send request
2022-07-01 02:45:31+0400 [Device] Send request
```

## Obtain Firmware ##

How to prepare (compile) a firmware is described [here](https://docs.espressif.com/projects/esp-at/en/latest/Compile_and_Develop/).

The latest firmware versions are available [here](https://github.com/espressif/esp-at/releases) - choose versions for ESP32C3-AT.

The used/tested firmware version is [v2.4.0.0](https://docs.espressif.com/projects/esp-at/en/release-v2.4.0.0/esp32c3).

It is already compiled and available [here](https://github.com/espressif/esp-at/files/8739863/ESP32-C3-MINI-1_AT_Bin_V2.4.0.0.zip).

## Flash Firmware Using Imp Application ##

A simple Squirrel example which flashes ESP32C3 chip:
- [imp-agent part](./Esp32LoaderExample.agent.nut) (provides REST API for firmware loading/reflashing)
- [imp-device part](./Esp32LoaderExample.device.nut)
- [ESP32Loader class](./Esp32Loader.device.nut) (implements esp32 reflashing over [Serial Protocol](https://docs.espressif.com/projects/esptool/en/latest/esp32c3/advanced-topics/serial-protocol.html))
- [script example linux bash](./esp32_send_fw.sh)(bash script to calculate file length and MD5, and send REST API requests)
- [script example windows cmd](./esp32_send_fw.bat)(cmd script to calculate file length and MD5, and send REST API requests)

For windows script example should be installed [curl](https://curl.se/windows/).

### REST API ###

`PUT https://<api_url><endpoint>`:
- `<api_url>` - imp-agent URL. It comprises the base URL `agent.electricimp.com` plus the [agent’s ID](https://developer.electricimp.com/faqs/terminology#agent). Example: `https://agent.electricimp.com/7jiDVu1t_w--`
- `<endpoint>` - an endpoint.
- No authentication is used.

Flashing procedure contains two steps:
1) Uploading needed binary files: `/esp32-load` endpoint - may be called several times for different files. But it is possible to transfer only one firmware file at a time.
Attantion! Binary files with length more then 256 kB should be splitted to parts. Split example [here](./esp32_send_fw.sh) and [here](./esp32_send_fw.bat).
2) Reboot esp32c3 chip to start the new uploaded firmware: `/esp32-reboot` endpoint - should be called once after all files are successfully uploaded.

#### PUT /esp32-load ####

Uploads a firmware binary file.

Parameters:
```
"flashOffset"  : 1000,              // ESP flash offset
"fileName"     : "e.g. bootloader", // name of firmware file (exact name is not important - used for logging only)
"md5"          : "8fe9e52b3e17d01fd06990f4f5381f5f" // firmware file MD5
```

For example: 
```
curl -X PUT -T ~/Develop/esp32/esp-at/build/partition_table/partition-table.bin "https://agent.electricimp.com/D7u-IqX1x6j1/esp32-load?fileName=partition-table.bin&flashOffset=0x8000&md5=76bc3722dae4b1f2e66c9f5649b31e02"
```

Log output example:
```
2022-06-24 00:42:24+0400 [Agent]  [INFO] PUT /esp32-load request from cloud
2022-06-24 00:42:25+0400 [Device] [INFO] Save MD5: 76bc3722dae4b1f2e66c9f5649b31e02
2022-06-24 00:42:25+0400 [Device] [INFO] Firmware image name: partition-table.bin
2022-06-24 00:42:25+0400 [Device] [INFO] Firmware image offset: 0x00008000
2022-06-24 00:42:25+0400 [Device] [INFO] Firmware image length: 3072
2022-06-24 00:42:25+0400 [Device] [INFO] Start erasing SPI flash from 0x0 to 0x1000
2022-06-24 00:42:26+0400 [Device] [INFO] Erasing finished!
2022-06-24 00:42:26+0400 [Device] [INFO] Start write to imp-device flash.
2022-06-24 00:42:26+0400 [Device] [INFO] Write to imp flash success. Load to the ESP32 started.
2022-06-24 00:42:29+0400 [Device] [INFO][ESP32Loader] Prepare success
2022-06-24 00:42:29+0400 [Device] [INFO][ESP32Loader] Send packet. Sequnce number: 0
2022-06-24 00:42:29+0400 [Device] [INFO][ESP32Loader] Send packet. Sequnce number: 1
2022-06-24 00:42:30+0400 [Device] [INFO][ESP32Loader] Send packet. Sequnce number: 2
2022-06-24 00:42:30+0400 [Agent]  [INFO] Load firmware success
2022-06-24 00:42:30+0400 [Device] [INFO][ESP32Loader] Verification MD5.
```

##### Firmware Files #####

| ESP Flash Offset | File |
| ---------------- | ---- |
| 0x0000  | bootloader/bootloader.bin |
| 0x8000  | partition_table/partition-table.bin |
| 0xf000  | phy_multiple_init_data.bin |
| 0xd000  | ota_data_initial.bin |
| 0x1e000 | at_customize.bin |
| 0x1f000 | customized_partitions/ble_data.bin |
| 0x25000 | customized_partitions/server_cert.bin |
| 0x27000 | customized_partitions/server_key.bin |
| 0x29000 | customized_partitions/server_ca.bin |
| 0x2b000 | customized_partitions/client_cert.bin |
| 0x2d000 | customized_partitions/client_key.bin |
| 0x2f000 | customized_partitions/client_ca.bin |
| 0x31000 | customized_partitions/factory_param.bin |
| 0x38000 | customized_partitions/mqtt_cert.bin |
| 0x3a000 | customized_partitions/mqtt_key.bin |
| 0x3c000 | customized_partitions/mqtt_ca.bin |
| 0x60000 | esp-at.bin |

**For the first flashing:** all files should be flashed. They can be flashed in any order but strictly one after another (not in parallel).

**For the next reflashings:** only files modified in the following versions should be written.

#### PUT /esp32-finish ####

Power off esp32c3 chip.

No arguments.

Log output example:
```
2022-06-29T21:14:13.359 +00:00 	[Agent] 	[INFO] PUT /esp32-finist request from cloud
2022-06-29T21:14:16.506 +00:00 	[Agent] 	[INFO] Chip power off success
```

## Flash Firmware Using External Tool ##

The following is needed for the flashing:
- A usb-uart converter (e.g. FT2232 FTDI).
- A flash utility. For Windows platform - [Flash download tool](https://www.espressif.com/sites/default/files/tools/flash_download_tool_3.9.2.zip), [another download tool](https://github.com/espressif/esptool).

ROM bootloader start for ESP32C3 is described [here](https://www.espressif.com/sites/default/files/documentation/esp32-c3_datasheet_en.pdf).
How to flash a firmware is described [here](https://docs.espressif.com/projects/esp-at/en/latest/Get_Started/Downloading_guide.html) and [here](https://docs.espressif.com/projects/esptool/en/latest/esp32c3/index.html).

Esptool command example:
esptool.py -t -p /dev/ttyUSB0 -b 115200 --no-stub --before=default_reset 
 --after=hard_reset write_flash --flash_mode dio --flash_freq 40m --flash_size 4MB 
 0x8000 partition_table/partition-table.bin

## Implementation Notes ##

Technical documentation for ESP32 is [here](https://www.espressif.com/en/support/documents/technical-documents).

### Example Settings ###

- Imp-device UART connected to the ESP ROM loader UART: `APP_ESP_UART` variable.

- Imp-device pins connected to the ESP chip strap pins: `APP_STRAP_PIN1`, `APP_STRAP_PIN2`, `APP_STRAP_PIN3` variables. These pins are used to switch ESP to the loading mode.

- Imp-device pin connected to the ESP ROM loader power enable pin: `APP_SWITCH_PIN` variable.

### ESP32Loader Class Usage ###

Interacts with the hardware ROM loader of the ESP32 chip over [Serial Protocol](https://docs.espressif.com/projects/esptool/en/latest/esp32c3/advanced-topics/serial-protocol.html)

Class usage:
1) Create ESP32Loader class object.
2) Start ROM loader.
3) Load firmware file/files (firmware file should be located on the Imp-Device SPI flash).
4) Reboot ESP32 chip.

#### Constructor ####

**First parameter**: Imp-Device pins connected to the ESP32 chip strapping pins:
```
   - "strappingPin1" Strapping pin 1 (for ESP32C3 GP9 BOOT)
   - "strappingPin2" Strapping pin 2 (for ESP32C3 EN  CHIP_EN)
   - "strappingPin3" Strapping pin 3 (for ESP32C3 GP8 PRINTF_EN)
```
For example:
```
    {
        "strappingPin1" : hardware.pinH,
        "strappingPin2" : hardware.pinE,
        "strappingPin3" : hardware.pinJ
    }
```

**Second parameter**: Imp-Device UART connected to the ESP32 ROM loader UART.
For example:
```
    hardware.uartPQRS
```

**Third parameter**: ESP32 chip SPI flash configuration.

Elements:
```
    - "id" Flash id (if not exist 0).
    - "totSize" Total flash size. (enum ESP32_LOADER_FLASH_SIZE).
    - "blockSize" Flash block size.
    - "sectSize" Flash sector size.
    - "pageSize" Flash page size.
    - "statusMask" Status mask (Default 65535).
```
For example:
```
    {"id"         : 0x00,
     "totSize"    : ESP32_LOADER_FLASH_SIZE.SZ4MB,
     "blockSize"  : 65536,
     "sectSize"   : 4096,
     "pageSize"   : 256,
     "statusMask" : 65535}
```

**Fourth parameter**: hardware pin connected to the ESP32 load switch.

For example:
```
    hardware.pinXU
```

#### Start chip ROM loader ####

Method `startROMLoader()` start ROM loader on chip. 

No arguments.

#### Load Firmware File ####

Method `load()` writes firmware file from the Imp-Device flash to the ESP flash.

The method is synchronous. No more than one load procedure should be called at a time.

**Method parameters**:
```
    - Firmware address in imp flash (source).
    - Firmware address in ESP flash (destination).
    - Firmware length (in bytes).
    - Firmware MD5 (string). Optional. 
```

If MD5 is specified: after writing firmware file is completed ROM loader calculate and compare MD5 checksum. Mismatch of MD5 checksum causes an error - `MD5 check failure`. 
If an MD5 check error occurs, repeat the file writing procedure.

#### Power off ESP32 ####

Method `finish()` resets the ESP32 chip and transfers control to the downloaded firmware.

No arguments.

#  Possible Improvements #

1) Add the use of the stub loader (second stage loader) firmware for the possibility of increasing the download speed.
2) Support compressed firmware files transfer. 
3) Test at higher UART baud rate (460800).

