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

@set CLASS_NAME = "ESP32Loader" // Class name for logging

// Enum for flash size coding system
enum ESP32_LOADER_FLASH_SIZE {
    SZ512KB   = 0x00,
    SZ256KB   = 0x10,
    SZ1MB     = 0x20,
    SZ2MB     = 0x30,
    SZ4MB     = 0x40,
    SZ2MBC1   = 0x50,
    SZ4MBC1   = 0x60,
    SZ8MB     = 0x80,
    SZ16MB    = 0x90
};

// Enum power state
enum ESP32_LOADER_POWER {
    OFF = 0,
    ON = 1
};

// The ROM loader sends the following error values
enum ESP32_LOADER_ERR {
    MSG_INV   = 0x05, // “Received message is invalid” (parameters or length field is invalid)
    FAIL_ACT  = 0x06, // “Failed to act on received message”
    INV_CRC   = 0x07, // “Invalid CRC in message”
    FLASH_WR  = 0x08, // “flash write error” - after writing a block of data to flash,
                      // the ROM loader reads the value back and the 8-bit CRC is compared
                      // to the data read from flash. If they don’t match, this error is returned.
    FLASH_RD  = 0x09, // “flash read error” - SPI read failed
    FLASH_LEN = 0x0a, // “flash read length error” - SPI read request length is too long
    DEFL      = 0x0b  // “Deflate error” (compressed uploads only)
};

// Supported ROM loader commands
enum ESP32_LOADER_CMD {
    FLASH_BEGIN      = 0x02, // Begin Flash Download. Four 32-bit words: size to erase, number of data packets,
                             // data size in one packet, flash offset.
    FLASH_DATA       = 0x03, // Flash Download Data. Four 32-bit words: data size, sequence number,
                             // 0, 0, then data. Uses Checksum.
    FLASH_END        = 0x04, // Finish Flash Download. One 32-bit word: 0 to reboot, 1 “run to user code”.
                             // Not necessary to send this command if you wish to stay in the loader.
    MEM_BEGIN        = 0x05, // Begin RAM Download Start. Total size, number of data packets,
                             // data size in one packet, memory offset.
    MEM_END          = 0x06, // Finish RAM Download. Two 32-bit words: execute flag, entry point address.
    MEM_DATA         = 0x07, // RAM Download Data. Four 32-bit words: data size, sequence number, 0, 0, then data.
                             // Uses Checksum.
    SYNC_FRAME       = 0x08, // Sync Frame. 36 bytes: 0x07 0x07 0x12 0x20, followed by 32 x 0x55.
    WRITE_REG        = 0x09, // Write 32-bit memory address. Four 32-bit words: address, value, mask and delay (in microseconds).
    READ_REG         = 0x0a, // Read 32-bit memory address. Address as 32-bit word. Read data as 32-bit word in value field.
    SPI_SET_PARAMS   = 0x0b, // Configure SPI flash. Six 32-bit words: id, total size in bytes, block size, sector size,
                             // page size, status mask.
    SPI_ATTACH       = 0x0d, // Attach SPI flash. 32-bit word: Zero for normal SPI flash. A second 32-bit word (should be 0) is passed
                             // to ROM loader only.
    CHANGE_BAUDRATE  = 0x0f, // Change Baud rate. Two 32-bit words: new baud rate, 0 if we are talking to the ROM flasher or
                             // the current/old baud rate if we are talking to the software stub flasher.
    FLASH_DEFL_BEGIN = 0x10, // Begin compressed flash download. Four 32-bit words: uncompressed size, number of data packets,
                             // data packet size, flash offset. With stub loader the uncompressed size is exact byte count to be written,
                             // whereas on ROM bootloader it is rounded up to flash erase block size.
    FLASH_DEFL_DATA  = 0x11, // Compressed flash download data. Four 32-bit words: data size, sequence number, 0, 0, then data. Uses Checksum.
                             // Error code 0xC1 on checksum error.
    FLASH_DEFL_END   = 0x12, // End compressed flash download. One 32-bit word: 0 to reboot, 1 to “run user code”.
                             // Not necessary to send this command if you wish to stay in the loader.
    SPI_FLASH_MD5    = 0x13  // Calculate MD5 of flash region. Four 32-bit words: address, size, 0, 0.
                             // Body contains 16 raw bytes of MD5 followed by 2 status bytes (stub loader) or
                             // 32 hex-coded ASCII (ROM loader) of calculated MD5.
};

// Internal constants:
// -------------------
// Default baudrate
const ESP32_LOADER_DEFAULT_BAUDRATE = 115200;
// Default word size
const ESP32_LOADER_DEFAULT_WORD_SIZE = 8;
// Default parity (PARITY_NONE)
const ESP32_LOADER_DEFAULT_PARITY = 0;
// Default count on stop bits
const ESP32_LOADER_DEFAULT_STOP_BITS = 1;
// Default control flags (NO_CTSRTS)
const ESP32_LOADER_DEFAULT_FLAGS = 4;
// Default RX FIFO size
const ESP32_LOADER_DEFAULT_RX_FIFO_SZ = 4096;

// Maximum amount of data expected to be received, in bytes
const ESP32_LOADER_MAX_DATA_LEN = 4096;
// Maximum time allowed for waiting for data, in seconds
const ESP32_LOADER_WAIT_DATA_TIMEOUT = 25;
// Checksum start seed
const ESP32_LOADER_CHECKSUM_SEED = 0xEF;
// Each SLIP packet begins and ends with 0xC0
const ESP32_LOADER_SLIP_PACK_IDENT = 0xC0;
// start 0xC0 index
const ESP32_LOADER_RESP_START_IND = 0x00;
// end 0xC0 index
const ESP32_LOADER_RESP_END_IND = 0x0D;
// response indication
const ESP32_LOADER_RESP_INDIC_IND = 0x01;
// response flag value
const ESP32_LOADER_RESP_INDIC_VALUE = 0x01;
// cmd index
const ESP32_LOADER_RESP_CMD_IND = 0x02;
// register value start index
const ESP32_LOADER_RESP_REG_VAL_IND = 0x05;
// status index (if data empty)
const ESP32_LOADER_RESP_STATUS_IND = 0x09;
// Response status success
const ESP32_LOADER_RESP_STATUS_SUCCESS = 0x00;
// MD5 index
const ESP32_LOADER_RESP_MD5_IND = 0x09;
// Direction index
const ESP32_LOADER_DIRECTION_IND = 0x01;
// Flash data checksum index
const ESP32_LOADER_CHECKSUM_IND = 0x05;
// Flash data start index in packet
const ESP32_LOADER_FLASH_DATA_IND = 0x19;
// This ROM address has a different value on each chip model
const ESP32_LOADER_CHIP_DETECT_MAGIC_REG_ADDR = 0x40001000
// ESP32C3 chip detect value
const ESP32_LOADER_ESP32C3_CHIP_DETECT_MAGIC_VALUE = 0x1B31506F;
// Transmit packet length
const ESP32_LOADER_TRANSMIT_PACKET_LEN = 1024;
// md5 length (ascii)
const ESP32_LOADER_MD5_ASCII_LEN = 32;
// Four 32-bit words: data size, sequence number, 0, 0, then data (16 bytes).
const ESP32_LOADER_FLASH_DATA_CFG_FIELD_LEN = 16;
// Go to loader timeout
const ESP32_ROM_LOADER_START_TIMEOUT = 0.5;

// ESP32 Loader Driver class.
// The class provides the ability to change the
// firmware of the ESP32C3 MCU.
class ESP32Loader {
    // Power switch pin
    _switchPin = null;
    // Hardware pins table for UART bootloader start
    _bootPins = null;
    // UART object
    _serial = null;
    // Flash parameters
    _espFlashParam = null;
    // Firmware packet sequence number
    _seqNumb = 0;
    // ESP32 firmware address in the imp flash
    _impFlashAddr = 0;
    // Current firmware size
    _fwImgLen = 0;
    // In loader flag
    _inLoader = false;

    /**
     * Constructor for ESP32 Loader Driver Class
     *
     * @param {table} bootPins - Hardware pins for ESP32 bootloader start.
     *      Boot pins table:
     *          "strappingPin1" : {object} Strapping pin 1
     *          "strappingPin2" : {object} Strapping pin 2
     *          "strappingPin3" : {object} Strapping pin 3
     * @param {object} uart - UART object connected to a ESP32 board.
     * @param {table} espFlashParam - External ESP32 SPI flash parameters (size value from ESP32_LOADER_FLASH_SIZE enum).
     *      Fields:
     *          "id"        : {integer} Flash id (if not exist 0).
     *          "totSize"   : {integer} Total flash size.
     *          "blockSize" : {integer} Flash block size.
     *          "sectSize"  : {integer} Flash sector size.
     *          "pageSize"  : {integer} Flash page size.
     *          "statusMask": {integer} Status mask.
     * @param {object} switchPin - Hardware pin object connected to load switch.
     */
    constructor(bootPins, uart, espFlashParam, switchPin) {
        _switchPin = switchPin;
        _bootPins = bootPins;
        _serial = uart;
        _espFlashParam = espFlashParam;
    }

    /**
     * Initiate the loading procedure.
     * Starts ROM loader (set strapping pins, configure UART, send SYNC and identify chip).
     *
     * @param {integer} baudRate - UART baud rate. Optional. Default: ESP32_LOADER_DEFAULT_BAUDRATE.
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function start(baudRate = ESP32_LOADER_DEFAULT_BAUDRATE) {
        if (_inLoader) {
            return Promise.resolve(null);
        }

        _switchPin.configure(DIGITAL_OUT, ESP32_LOADER_POWER.ON);
        imp.sleep(ESP32_ROM_LOADER_START_TIMEOUT);

        local strappingPin3 = "strappingPin3" in _bootPins ? _bootPins.strappingPin3 : null;
        local strappingPin1 = "strappingPin1" in _bootPins ? _bootPins.strappingPin1 : null;
        local strappingPin2 = "strappingPin2" in _bootPins ? _bootPins.strappingPin2 : null;

        strappingPin3 && strappingPin3.configure(DIGITAL_OUT, 1);
        strappingPin1 && strappingPin1.configure(DIGITAL_OUT, 1);
        strappingPin2 && strappingPin2.configure(DIGITAL_OUT, 0);
        imp.sleep(ESP32_ROM_LOADER_START_TIMEOUT);

        strappingPin1 && strappingPin1.write(0);
        strappingPin2 && strappingPin2.write(1);
        imp.sleep(ESP32_ROM_LOADER_START_TIMEOUT);

        strappingPin1 && strappingPin1.write(1);

        _serial.setrxfifosize(ESP32_LOADER_DEFAULT_RX_FIFO_SZ);
        _serial.configure(ESP32_LOADER_DEFAULT_BAUDRATE,
                          ESP32_LOADER_DEFAULT_WORD_SIZE,
                          ESP32_LOADER_DEFAULT_PARITY,
                          ESP32_LOADER_DEFAULT_STOP_BITS,
                          ESP32_LOADER_DEFAULT_FLAGS);

        _inLoader = true;

        // SYNC packet:
        // C00008240000000000070712205555555555555555555555555
        // 555555555555555555555555555555555555555C0
        // The checksum field is ignored (can be zero) for all comands
        // except for MEM_DATA, FLASH_DATA, and FLASH_DEFL_DATA.
        local syncStr = "C0000824000000000007071220" +
                        "5555555555555555555555555555555555555555555555555555555555555555C0";
        // sync packet response validate
        // wait for answer
        // C0010804000712205500000000C0
        // the first 4 sync packets usually come with no result
        local dummyValidator = @(data, _) null;
        local syncMsgValidator = @(data, _) _basicRespCheck(data, ESP32_LOADER_CMD.SYNC_FRAME) ?
                                            null :
                                            "Sync message failure";
        // read chip identify register
        local identChipStr = format("C0000A040000000000%08XC0",
                                    swap4(ESP32_LOADER_CHIP_DETECT_MAGIC_REG_ADDR));
        // identify chip
        // wait for answer for ESP32 eg.
        // C0010a0400831DF00000000000C0
        local chipNameValidator = @(data, _) _basicRespCheck(data,
                                                             ESP32_LOADER_CMD.READ_REG,
                                                             ESP32_LOADER_ESP32C3_CHIP_DETECT_MAGIC_VALUE) ?
                                              null :
                                              "Chip name identify failure";
        // change baud rate command. Request example: c0000f0800000000000008070000000000c0
        // Response example: c0010f0400f784000000000000c0
        local changeBaudRateStr = format("C0000F080000000000%08X00000000C0",
                                         swap4(baudRate));
        local changeBaudRateValidator = @(data, _) _basicRespCheck(data,
                                                                   ESP32_LOADER_CMD.CHANGE_BAUDRATE) ?
                                                                   null :
                                                                   "Change baud rate failure";;

        // Functions that return promises which will be executed serially
        local promiseFuncs = [
            // Wait for response sync message (5 attempts)
            _communicate(syncStr, dummyValidator),
            _communicate(syncStr, dummyValidator),
            _communicate(syncStr, dummyValidator),
            _communicate(syncStr, dummyValidator),
            _communicate(syncStr, syncMsgValidator),
            // identify chip
            _communicate(identChipStr, chipNameValidator)
        ];

        if (baudRate != ESP32_LOADER_DEFAULT_BAUDRATE) {
            promiseFuncs.append(_communicate(changeBaudRateStr, changeBaudRateValidator));
        }

        return Promise.serial(promiseFuncs)
        .then(function(_) {
            // setting a new baud rate if it is not equal to the default baud rate
            if (baudRate != ESP32_LOADER_DEFAULT_BAUDRATE) {
                ::info("UART baud rate is changed to: " + baudRate, "@{CLASS_NAME}");
                _serial.disable();
                _serial.setrxfifosize(ESP32_LOADER_DEFAULT_RX_FIFO_SZ);
                _serial.configure(baudRate,
                                  ESP32_LOADER_DEFAULT_WORD_SIZE,
                                  ESP32_LOADER_DEFAULT_PARITY,
                                  ESP32_LOADER_DEFAULT_STOP_BITS,
                                  ESP32_LOADER_DEFAULT_FLAGS);
            }
        }.bindenv(this))
        .fail(function(err) {
            // Disable everything
            finish();
            throw err;
        }.bindenv(this));
    }

    /**
     * Load firmware to ESP. Writes firmware file to the ESP chip SPI flash.
     * The method must be called only after the previous call is completed.
     *
     * @param {integer} impFlashAddr - Firmware address in imp flash.
     * @param {integer} espFlashAddr - Firmware address in ESP flash.
     * @param {integer} fwImgLen - Firmware length.
     * @param {string}  fwMD5 - Firmware MD5. Optional.
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function load(impFlashAddr, espFlashAddr, fwImgLen, fwMD5 = null) {
        if (!_inLoader) {
            return Promise.reject("ROM loader is not started");
        }

        return _prepare(impFlashAddr, espFlashAddr, fwImgLen)
        .then(function(_) {
            ::info("Preparing is done", "@{CLASS_NAME}");
            return _sendDataPackets();
        }.bindenv(this))
        .then(function(_) {
            ::info("Data packets were sent successfully", "@{CLASS_NAME}");
            return _checkHash(espFlashAddr, fwImgLen, fwMD5);
        }.bindenv(this));
    }

    /**
     *  Finish loading procedure. Powers off ESP32 chip and all pins/ports used to interact with it.
     *  NOTE: It's assumed that if the switch pin is disabled, the ES32 module is off.
     *
     *  @return {Promise} that:
     *  - resolves if the operation succeeded
     *  - rejects if the operation failed
     */
    function finish() {
        _inLoader = false;
        _switchPin.disable();
        _serial.disable();

        foreach (pin in _bootPins) {
            pin.disable();
        }

        return Promise.resolve(null);
    }

    // ---------------- PRIVATE METHODS ---------------- //

    /**
     * Prepare ROM loader to receive firmware.
     *
     * @param {integer} impFlashAddr - Firmware image address (in imp flash).
     * @param {integer} espFlashAddr - Firmware image address (in ESP flash).
     * @param {integer} fwImgLen     - Firmware image length.
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function _prepare(impFlashAddr, espFlashAddr, fwImgLen) {
        if (fwImgLen == 0) {
            return Promise.reject("Firmware image length is 0");
        }

        _impFlashAddr = impFlashAddr;
        _fwImgLen = fwImgLen;
        _seqNumb = 0;

        // attach spi flash
        local spiFlashAttachStr = "C0000D0800000000000000000000000000C0";
        // check attach flash
        // wait for answer for ESP32 eg.
        // C0010D040038FF122A00000000C0
        local spiFlashAttachValidator = @(data, _) _basicRespCheck(data, ESP32_LOADER_CMD.SPI_ATTACH) ?
                                                    null :
                                                    "Flash attach failure";
        // set spi flash parameters (id, total size in bytes, block size, sector size, page size, status mask)
        // everything except the flash size is fixed
        local spiSetParamStr = format("C0000B180000000000%08X%08X%08X%08X%08X%08XC0",
                                      swap4(_espFlashParam.id),
                                      swap2(_espFlashParam.totSize),
                                      swap4(_espFlashParam.blockSize),
                                      swap4(_espFlashParam.sectSize),
                                      swap4(_espFlashParam.pageSize),
                                      swap4(_espFlashParam.statusMask));
        // check spi flash parameters
        local spiFlashParamValidator = @(data, _) _basicRespCheck(data, ESP32_LOADER_CMD.SPI_SET_PARAMS) ?
                                                   null :
                                                   "Flash parameter set failure";
        // FLASH_BEGIN - erasing flash (size to erase, number of data packets, data size in one packet, flash offset)
        local numberOfDataPackets = (fwImgLen + ESP32_LOADER_TRANSMIT_PACKET_LEN - 1) / ESP32_LOADER_TRANSMIT_PACKET_LEN;
        // NOTE: THIS DOES NOT MATCH THE DOCUMENTATION!!!
        // 4 BYTES DIFFERENCE
        // https://docs.espressif.com/projects/esptool/en/latest/esp32c3/advanced-topics/serial-protocol.html
        local flashBeginStr = format("C00002140000000000%08X%08X%08X%08X00000000C0",
                                     swap4(fwImgLen),
                                     swap4(numberOfDataPackets),
                                     swap4(ESP32_LOADER_TRANSMIT_PACKET_LEN),
                                     swap4(espFlashAddr));
        // flash begin command validator
        local flashBeginValidator =  @(data, _) _basicRespCheck(data, ESP32_LOADER_CMD.FLASH_BEGIN) ?
                                                 null :
                                                 "ESP flash erase failure";
        // Functions that return promises which will be executed serially
        local promiseFuncs = [
            // attach spi flash
            _communicate(spiFlashAttachStr, spiFlashAttachValidator),
            // set spi flash param
            _communicate(spiSetParamStr, spiFlashParamValidator),
            // erasing flash
            _communicate(flashBeginStr, flashBeginValidator)
        ];

        return Promise.serial(promiseFuncs);
    }

    /**
     * Send data packets from imp flash to the ESP flash.
     *
     * @return {Promise} that:
     *  - resolves if the operation succeeded
     *  - rejects if the operation failed
     */
    function _sendDataPackets() {
        local continueFunction = @() _fwImgLen > 0;
        return Promise.loop(continueFunction.bindenv(this),
                            _sendDataPacket.bindenv(this));
    }

    /**
     * Send data packet. Cmd FLASH_DATA.
     *
     * @return {Promise} that:
     *  - resolves if the operation succeeded
     *  - rejects if the operation failed
     */
    function _sendDataPacket() {
        ::info("Send packet. Sequence number: " + _seqNumb, "@{CLASS_NAME}");
        // data packet
        local flashData = utilities.hexStringToBlob(format("C00003%04X00000000%08X%08X0000000000000000",
                                                           swap2(ESP32_LOADER_TRANSMIT_PACKET_LEN +
                                                                 ESP32_LOADER_FLASH_DATA_CFG_FIELD_LEN),
                                                           swap4(ESP32_LOADER_TRANSMIT_PACKET_LEN),
                                                           swap4(_seqNumb)));
        // flash data validator
        local flashDataValidator = @(data, _) _basicRespCheck(data, ESP32_LOADER_CMD.FLASH_DATA) ?
                                               null :
                                               "Write data failure";
        local dataLen = 0;
        local tailLen = 0;

        if (_fwImgLen >= ESP32_LOADER_TRANSMIT_PACKET_LEN) {
            dataLen = ESP32_LOADER_TRANSMIT_PACKET_LEN;
        } else {
            dataLen = _fwImgLen;
            tailLen = ESP32_LOADER_TRANSMIT_PACKET_LEN - dataLen;
        }

        // set to end
        flashData.seek(0, 'e');
        // enable imp flash
        hardware.spiflash.enable();
        hardware.spiflash.readintoblob(_impFlashAddr, flashData, dataLen);
        hardware.spiflash.disable();

        // supplement the package 0xFFFFFFFF.....FFFFF to ESP32_LOADER_TRANSMIT_PACKET_LEN
        for (local i = 0; i < tailLen; i++) {
            flashData.writen(0xFF, 'b');
        }

        // add last C0
        flashData.writen(ESP32_LOADER_SLIP_PACK_IDENT, 'b');
        // set to begin
        flashData.seek(0, 'b');
        // calculate checksum
        _checksumCalc(flashData);
        // increase flash address
        _impFlashAddr += dataLen;
        // decrease firmware image length
        _fwImgLen -= dataLen;
        // increase sequence number
        _seqNumb++;

        return _communicate(flashData, flashDataValidator, null, false);
    }

    /**
     * Check MD5 of downloaded firmware image.
     *
     * @param {integer} espFlashAddr - Firmware image address (in ESP flash).
     * @param {integer} fwImgLen     - Firmware image length.
     * @param {string}  fwMD5        - Firmware MD5.
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function _checkHash(espFlashAddr, fwImgLen, fwMD5) {
        if (fwMD5 == null) {
            ::debug("No MD5 checksum passed", "@{CLASS_NAME}");
            return Promise.resolve(null);
        }

        ::info("Verification MD5.", "@{CLASS_NAME}");

        // hash verify request
        local hashVerifyStr = format("C00013100000000000%08X%08X0000000000000000C0",
                                     swap4(espFlashAddr),
                                     swap4(fwImgLen));
        // hash validator (compare MD5 values)
        local hashValidator =  @(data, _) (!data.seek(ESP32_LOADER_RESP_MD5_IND, 'b') &&
                                           data.readstring(ESP32_LOADER_MD5_ASCII_LEN) == fwMD5) ?
                                           null :
                                           "MD5 check failure";

        return _communicate(hashVerifyStr, hashValidator, null, false);
    }

    /**
     * Communicate with the ESP32 board: send a command (if passed) and wait for a reply
     *
     * @param {string | blob | null} cmd - String with a command to send or null
     * @param {function} validator - Function that checks if a reply has been fully received
     * @param {function} [replyHandler=null] - Handler that is called to process the reply
     * @param {boolean} [wrapInAFunc=true] - True to wrap the Promise to be returned in an additional function with no params.
     *                                       This optionis useful for, e.g., serial execution of a list of promises (Promise.serial)
     *
     * @return {Promise | function}: Promise or a function with no params that returns this promise. The promise:
     * - resolves with the reply (pre-processed if a reply handler specified) if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function _communicate(cmd, validator, replyHandler = null, wrapInAFunc = true) {
        if (wrapInAFunc) {
            return (@() _communicate(cmd, validator, replyHandler, false)).bindenv(this);
        }

        if (cmd) {
            local blobCmd = typeof(cmd) == "string" ? utilities.hexStringToBlob(cmd) : cmd;
            try {
                _serial.write(_checkSLIPPack(blobCmd));
            } catch(exp) {
                ::error("Exception during UART write: " + exp, "@{CLASS_NAME}");
                return Promise.reject("UART write failure");
            }
        }

        return _waitForData(validator)
        .then(function(reply) {
            return replyHandler ? replyHandler() : reply;
        }.bindenv(this));
    }

    /**
     * Wait for certain data to be received from the ESP32 board
     *
     * @param {function} validator - Function that checks if the expected data has been fully received
     *
     * @return {Promise} that:
     * - resolves with the data received if the operation succeeded
     * - rejects if the operation failed
     */
    function _waitForData(validator) {
        // Data check/read period, in seconds
        const ESP32_LOADER_DATA_CHECK_PERIOD = 0.1;
        // Maximum data length expected to be received from ESP32, in bytes
        const ESP32_LOADER_DATA_READ_CHUNK_LEN = 1024;

        local start = hardware.millis();
        local data = blob();

        return Promise(function(resolve, reject) {
            local check;
            check = function() {
                local chunk = _serial.readblob(ESP32_LOADER_DATA_READ_CHUNK_LEN);
                // Read until FIFO is empty and accumulate to the result string
                while (chunk.len() > 0 &&
                       data.len() < ESP32_LOADER_MAX_DATA_LEN) {
                    data.writeblob(chunk);
                    chunk = _serial.readblob(ESP32_LOADER_DATA_READ_CHUNK_LEN);
                }

                local timeElapsed = (hardware.millis() - start) / 1000.0;

                local valResult = validator(data, timeElapsed);
                if (valResult == null) {
                    return resolve(data);
                }

                if (timeElapsed >= ESP32_LOADER_WAIT_DATA_TIMEOUT) {
                    return reject(valResult);
                }

                if (data.len() >= ESP32_LOADER_MAX_DATA_LEN) {
                    return reject("Too much data received but still no expected data");
                }

                imp.wakeup(ESP32_LOADER_DATA_CHECK_PERIOD, check);
            }.bindenv(this);

            imp.wakeup(ESP32_LOADER_DATA_CHECK_PERIOD, check);
        }.bindenv(this));
    }

    /**
     * Calculate and add checksum to the packet.
     *
     * @param {blob} data - Flash data packet.
     */
    function _checksumCalc(data) {
        local val = ESP32_LOADER_CHECKSUM_SEED;
        for (local i = 0;
             i < ESP32_LOADER_TRANSMIT_PACKET_LEN;
             i++) {
            val = (val ^ data[ESP32_LOADER_FLASH_DATA_IND + i]);
        }

        data[ESP32_LOADER_CHECKSUM_IND] = val;
    }

    /**
     * Within the packet, all occurrences of 0xC0 and 0xDB are
     * replaced with 0xDB 0xDC and 0xDB 0xDD, respectively.
     *
     * @param {blob} data - Flash data packet.
     */
    function _checkSLIPPack(data) {
        local res = blob();
        local len = data.len();

        for (local i = 0; i < len; i++) {
            local b = data[i];

            if (b == 0xDB) {
                // Little-endian
                res.writen(0xDDDB, 'w');
            } else if (i * (i - len + 1) != 0 && b == 0xC0) {
                // Little-endian
                res.writen(0xDCDB, 'w');
            } else {
                res.writen(b, 'b');
            }
        }

        return res;
    }

    /**
     * Check main packet content.
     * Return true if packet is complete (C0...C0),
     * status is ok (0), response flag value - 1, req. cmd. == resp. cmd.
     *
     * @param {blob} data - Flash data packet.
     * @param {integer} checkCmd - Loader command.
     * @param {integer} chipId - Chip id. Optional.
     *
     * @return {bool} True if OK, otherwise - false.
     */
    function _basicRespCheck(data, checkCmd, chipId = null) {
        if (data.len() <= ESP32_LOADER_RESP_END_IND) {
            return false;
        }

        local chipIdMatch = true;

        if (chipId != null) {
            data.seek(ESP32_LOADER_RESP_REG_VAL_IND, 'b');
            chipIdMatch = data.readn('i') == chipId;
        }

        return data[ESP32_LOADER_RESP_START_IND] == ESP32_LOADER_SLIP_PACK_IDENT &&
               data[ESP32_LOADER_RESP_END_IND] == ESP32_LOADER_SLIP_PACK_IDENT &&
               data[ESP32_LOADER_RESP_INDIC_IND] == ESP32_LOADER_RESP_INDIC_VALUE &&
               data[ESP32_LOADER_RESP_STATUS_IND] == ESP32_LOADER_RESP_STATUS_SUCCESS &&
               data[ESP32_LOADER_RESP_CMD_IND] == checkCmd &&
               chipIdMatch;
    }
}

@set CLASS_NAME = null // Reset the variable
