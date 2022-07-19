# ESP32 Firmware #

How to flash/reflash ESP-AT firmware for the [esp32-c3fn4 chip (ESP32-C3 Series)](https://www.espressif.com/sites/default/files/documentation/esp32-c3_datasheet_en.pdf) used in the Prog-X Asset Tracker module.

## Check Current Firmware ##

A simple Squirrel test for imp-device which gets a version from ESP32 - [Esp32Test.device.nut](./Esp32Test.device.nut)

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

A log when ESP32 chip has no firmware:
```
2022-07-01 02:43:31+0400 [Device] Send request
2022-07-01 02:44:31+0400 [Device] Send request
2022-07-01 02:45:31+0400 [Device] Send request
```

## ESP32Loader Class ##

A Squirrel class for imp-device which implements esp32c3 reflashing over [Serial Protocol](https://docs.espressif.com/projects/esptool/en/latest/esp32c3/advanced-topics/serial-protocol.html) - [ESP32Loader.device.nut](./Esp32Loader.device.nut) - this is the main class which is utilized by the firmware reflashing example and other (eg. factory) applications.

A simple Squirrel test for ESP32Loader class - [Esp32LoaderSimpleTest.device.nut](./Esp32LoaderSimpleTest.device.nut)

## Obtain Firmware ##

How to prepare (compile) a firmware is described [here](https://docs.espressif.com/projects/esp-at/en/latest/Compile_and_Develop/).

The latest firmware versions are available [here](https://github.com/espressif/esp-at/releases) - choose versions for ESP32C3-AT.

The used/tested firmware version is [v2.4.0.0](https://docs.espressif.com/projects/esp-at/en/release-v2.4.0.0/esp32c3).

It is already compiled and available [here](https://github.com/espressif/esp-at/files/8739863/ESP32-C3-MINI-1_AT_Bin_V2.4.0.0.zip).

## Flash Firmware Using Imp Application ##

A simple Squirrel example which flashes ESP32C3 chip:
- [imp-agent part](./Esp32LoaderExample.agent.nut) (provides REST API for firmware loading/reflashing)
- [imp-device part](./Esp32LoaderExample.device.nut)
- [bash script](./esp32_send_fw.sh) which calculates a firmware file length and MD5, splits the file into parts and sends REST API requests.
  - Originally the script is intended for Linux bash.
  - To run the script eg. on Windows, install [git (with bash component)](http://git-scm.com/download/win) and execute the script with git bash terminal.

### REST API ###

`PUT https://<api_url><endpoint>`:
- `<api_url>` - imp-agent URL. It comprises the base URL `agent.electricimp.com` plus the [agent’s ID](https://developer.electricimp.com/faqs/terminology#agent). Example: `https://agent.electricimp.com/7jiDVu1t_w--`
- `<endpoint>` - an endpoint.
- No authentication is used.

Flashing procedure contains two steps:
1) Uploading needed binary files: `/esp32-load` endpoint - may be called several times for different files. But it is possible to transfer only one firmware file at a time.
2) Finishing the procedure (reboot esp32c3 chip to start the new uploaded firmware): `/esp32-finish` endpoint - should be called once after all files are successfully uploaded.

#### PUT /esp32-load ####

Uploads a firmware binary file.

Parameters:
```
flashOffset=<number> - offset in the ESP flash memory where to load the file, eg. 0000
fileName=<string> - name of the file, eg. bootloader. Exact name is not important, it is used for logging purpose only.
md5=<string> - MD5 of the file, eg. 8fe9e52b3e17d01fd06990f4f5381f5f
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

The files to flash and the corresponding offsets in the ESP32C3 flash memory for the used/tested firmware version:

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

**For the next reflashings:** only files modified in the new versions need to be reflashed (no need to reflash unmodified files if their offsets are not changed).

**Attention!** The example may not accept files with the length more than 256 KBytes:
- In this case the file should be split into parts before uploading.
- Every part should be uploaded as an individual file.
- Note: a correspondingly adjusted ESP Flash Offset should be specified for every part.

Note, the provided [script](./esp32_send_fw.sh) does the needed splitting (as well as the length and MD5 calculations).

#### PUT /esp32-finish ####

Finishes the reflashing procedure, restarts esp32 chip, new firmware is run after that.

No parameters.

Log output example:
```
2022-06-29T21:14:13.359 +00:00 	[Agent] 	[INFO] PUT /esp32-finish request from cloud
2022-06-29T21:14:16.506 +00:00 	[Agent] 	[INFO] Chip power off success
```

## Flash Firmware Using External Tool ##

The following is needed for the flashing:
- A usb-uart converter (e.g. FT2232 FTDI).
- A flash utility
  - [Flash download tool for Windows](https://www.espressif.com/sites/default/files/tools/flash_download_tool_3.9.2.zip),
  - [Esptool (Python-based)](https://github.com/espressif/esptool).
- Switch ESP32 to the loading mode.

How to switch ESP32C3 to the loading mode is described [here](https://www.espressif.com/sites/default/files/documentation/esp32-c3_datasheet_en.pdf).

How to flash a firmware is described [here](https://docs.espressif.com/projects/esp-at/en/latest/Get_Started/Downloading_guide.html) and [here](https://docs.espressif.com/projects/esptool/en/latest/esp32c3/index.html).

Esptool command example:
```
esptool.py -t -p /dev/ttyUSB0 -b 115200 --no-stub --before=default_reset
 --after=hard_reset write_flash --flash_mode dio --flash_freq 40m --flash_size 4MB
 0x8000 partition_table/partition-table.bin
```

## Implementation Notes ##

Technical documentation for ESP32 is [here](https://www.espressif.com/en/support/documents/technical-documents) (choose "ESP32-C3 Series").

### ESP32Loader Class Usage ###

Interacts with the hardware ROM loader of the ESP32 chip over [Serial Protocol](https://docs.espressif.com/projects/esptool/en/latest/esp32c3/advanced-topics/serial-protocol.html)

Firmware loading procedure contains three steps:
1) Start loading procedure - method start().
2) Load firmware file/files - method load(). Firmware file should be located on the Imp-Device SPI flash. Several files can be loaded, but strictly one after another (not in parallel).
3) Finish loading procedure - method finish(). It reboots ESP32 chip and run the new loaded firmware.

Every new loading procedure should be initiated by the start() method.

#### Constructor ####

**First parameter**: Imp-Device pins connected to the ESP32 chip strapping pins - are used to switch ESP to the loading mode.
```
   - "strappingPin1" Strapping pin 1 (for ESP32C3 GP9 BOOT)
   - "strappingPin2" Strapping pin 2 (for ESP32C3 EN  CHIP_EN)
   - "strappingPin3" Strapping pin 3 (for ESP32C3 GP8 PRINTF_EN)
```

Example for the Prog-X Asset Tracker module:
```
    {
        "strappingPin1" : hardware.pinH,
        "strappingPin2" : hardware.pinE,
        "strappingPin3" : hardware.pinJ
    }
```

**Second parameter**: Imp-Device UART connected to the ESP32 ROM loader UART.

Example for the Prog-X Asset Tracker module:
```
    hardware.uartPQRS
```

**Third parameter**: ESP32 chip SPI flash configuration.
```
    - "id" Flash id (0 if does not exist).
    - "totSize" Total flash size. (enum ESP32_LOADER_FLASH_SIZE).
    - "blockSize" Flash block size.
    - "sectSize" Flash sector size.
    - "pageSize" Flash page size.
    - "statusMask" Status mask (Default 65535).
```

Example for the Prog-X Asset Tracker module:
```
    {"id"         : 0x00,
     "totSize"    : ESP32_LOADER_FLASH_SIZE.SZ4MB,
     "blockSize"  : 65536,
     "sectSize"   : 4096,
     "pageSize"   : 256,
     "statusMask" : 65535}
```

**Fourth parameter**: Imp-Device pin connected to the ESP32 load switch.

Example for the Prog-X Asset Tracker module:
```
    hardware.pinXU
```

#### Start ####

Method `start()` initiates the loading procedure.

No parameters.

#### Load ####

Method `load()` writes firmware file from the Imp-Device SPI flash to the ESP chip SPI flash.

The method is synchronous. No more than one load procedure should be called at a time.

**Method parameters**:
```
    - Firmware address in imp flash (source).
    - Firmware address in ESP flash (destination).
    - Firmware length (in bytes).
    - Firmware MD5 (string). Optional.
```

If MD5 is specified:
- After the file is written to the ESP flash, ESP bootloader calculates and compares the MD5 checksum.
- Mismatch of the MD5 checksum causes an error - `MD5 check failure`.

#### Finish ####

Method `finish()` completes the loading procedure, resets the ESP32 chip and transfers control to the loaded firmware.

No parameters.

#  Possible Improvements #

1) Load and use an alternative bootloader - ["stub loader"](https://docs.espressif.com/projects/esptool/en/latest/esp32/esptool/flasher-stub.html) - it can increase the download speed.
2) Support compressed firmware files transfer.
3) Test at higher UART baud rate (460800).
