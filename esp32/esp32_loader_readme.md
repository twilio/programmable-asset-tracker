# ESP32 Loader Example #

This software is usage example of ESP32Loader class.

Software files are downloaded using REST API (PUT requests) on imp-agent.
List of REST API endpoints:
1)  /esp32-load
3)  /esp32-reboot 

Endpoint `/esp32-load` is using for sending firmware file. 

Parameters:
```
"fileName"     : "e.g. bootloader", // name of firmware file 
"fileLen"      : 8756, // not deflated firmware file size
"flashOffset"  : 1000, // ESP flash offset
"deflate"      : false, // is deflated? not implemented yet, always false
"md5"          : "8fe9e52b3e17d01fd06990f4f5381f5f" // firmware file MD5
```
For example: 
```
curl -X PUT -T ~/Develop/esp32/esp-at/build/partition_table/partition-table.bin "https://agent.electricimp.com/D7u-IqX1x6j1/esp32-load?fileName=partition-table.bin&fileLen=3072&flashOffset=0x8000&deflate=false&md5=76bc3722dae4b1f2e66c9f5649b31e02"
```
Output example:
```
2022-06-24 00:42:24+0400 [Agent]  [INFO] PUT /esp32-load request from cloud
2022-06-24 00:42:25+0400 [Device] [INFO] Save MD5: 76bc3722dae4b1f2e66c9f5649b31e02
2022-06-24 00:42:25+0400 [Device] [INFO] Firmware image name: partition-table
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
Endpoint `/esp32-reboot` is using for the start downloaded firmware after writing all files to the flash.
No authentication required. It is possible to transfer only one firmware file at a time.

## ESP ROM loader UART ##

Imp-device UART connected to the ESP ROM loader UART is set using `APP_ESP_UART` global variable.

## ESP ROM loader strap pins ##

The transition to the loading mode is carried out by actions on the strapping pins.
Imp-device pins connected to the ESP chip strap pins are set using `APP_STRAP_PIN1`, `APP_STRAP_PIN2`, `APP_STRAP_PIN3` global variables.
ESP strap pins are described to the [ESP32WROOM32, ESP32C3 MCU datasheets](https://www.espressif.com/en/support/documents/technical-documents).

## ESP ROM loader power enable pin ##

ESP power enable pin is set using `APP_SWITCH_PIN` global variable.

# ESP32Loader class usage #

The ESP32Loader class interacts with the hardware ROM loader of the ESP32 chip. Class load and start new firmware on ESP32 chip.

Class usage:
1) Create ESP32Loader class object.
2) Load firmware file/files (firmware file must be located on the imp flash).
3) Reboot ESP32 chip.

## ESP32Loader class constructor parameters ##

First parameter is Imp-Device pins connected to the ESP32 chip strapping pins:
```
   - "strappingPin1" Strapping pin 1 (for ESP32C3 GP9 BOOT)
   - "strappingPin2" Strapping pin 2 (for ESP32C3 EN CHIP_EN)
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

Second parameter is Imp-Device UART connected to the ESP32 ROM loader UART.
For example:
```
    hardware.uartPQRS
```
Third parameter is ESP32 chip SPI flash configuration.

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
    {
        "id"         : 0x00,
        "totSize"    : ESP32_LOADER_FLASH_SIZE.SZ4MB,
        "blockSize"  : 65536,
        "sectSize"   : 4096,
        "pageSize"   : 256,
        "statusMask" : 65535
    }
```
Fourth parameter is hardware pin connected to the ESP32 load switch.

For example:
```
    hardware.pinXU
```
## Load firmware file ##

ESP32Loader class is using imp SPI flash for storage ESP firmware.
Method `load` of the ESP32Loader class  write firmware file from Imp-Device flash to the ESP flash.

Method arguments:
```
    - Firmware address in imp flash (source).
    - Firmware address in ESP flash (destination).
    - Firmware length (in bytes).
    - Firmware MD5 (string). Optional. 
```

## Final reboot ##

After all files are uploaded. Method `reboot` resets the ESP32 chip and transfers control to the downloaded program.

#  Possible improvements #

1) Add the use of the stub loader firmaware. 
2) Add transfer of compressed firmware files. 
3) Test at higher UART baud rate (460800).

