#require "Messenger.lib.nut:0.2.0"
#require "Promise.lib.nut:4.0.0"
#require "utilities.lib.nut:3.0.1"

@include once "../src/shared/Logger/Logger.shared.nut"
@include once "Esp32Loader.device.nut"

// The available range for erasing
const APP_FLASH_START_ADDR = 0x000000;
const APP_FLASH_END_ADDR = 0x200000;
// Flash sector size
const APP_SECTOR_SIZE = 0x1000;

// Messenger message names
enum APP_M_MSG_NAME {
    INFO = "info",
    DATA = "data",
    ESP_FINISH = "finish"
};

class FlipFlop {
    _clkPin = null;
    _switchPin = null;

    constructor(clkPin, switchPin) {
        _clkPin = clkPin;
        _switchPin = switchPin;
    }

    function _get(key) {
        if (!(key in _switchPin)) {
            throw null;
        }

        // We want to clock the flip-flop after every change on the pin. This will trigger clocking even when the pin is being read.
        // But this shouldn't affect anything. Moreover, it's assumed that DIGITAL_OUT pins are read rarely.
        // To "attach" clocking to every pin's function, we return a wrapper-function that calls the requested original pin's
        // function and then clocks the flip-flop. This will make it transparent for the other components/modules.
        // All members of hardware.pin objects are functions. Hence we can always return a function here
        return function(...) {
            // Let's call the requested function with the arguments passed
            vargv.insert(0, _switchPin);
            // Also, we save the value returned by the original pin's function
            local res = _switchPin[key].acall(vargv);

            // Then we clock the flip-flop assuming that the default pin value is LOW (externally pulled-down)
            _clkPin.configure(DIGITAL_OUT, 1);
            _clkPin.disable();

            // Return the value returned by the original pin's function
            return res;
        };
    }
}

// Imp UART connected to the ESP32C3
APP_ESP_UART <- hardware.uartPQRS;
// ESP32 power on/off pin
APP_SWITCH_PIN <- FlipFlop(hardware.pinYD, hardware.pinS);
// Strap pin 1 (ESP32C3 GP9 BOOT)
APP_STRAP_PIN1 <- hardware.pinH;
// Strap pin 2 (ESP32C3 EN CHIP_EN)
APP_STRAP_PIN2 <- hardware.pinE;
// Strap pin 3 (ESP32C3 GP8 PRINTF_EN)
APP_STRAP_PIN3 <- hardware.pinJ;

// Flash parameters
APP_ESP_FLASH_PARAM <- {"id"         : 0x00,
                        "totSize"    : ESP32_LOADER_FLASH_SIZE.SZ4MB,
                        "blockSize"  : 65536,
                        "sectSize"   : 4096,
                        "pageSize"   : 256,
                        "statusMask" : 65535};

// ESP32 loader example device application
class Application {
    // Messenger instance
    _msngr = null;
    // ESP32 loader instance
    _espLoader = null;
    // MD5 values of all firmware image
    _md5Sum = null;
    // load process is active
    _isActive = false;
    // ESP32 flash address
    _offset = null;
    // Imp SPI flash write address
    _writeAddr = null;
    // length of stored data
    _writeLen = null;
    // firmware image length
    _len = null;
    // Firmware image file name
    _fwName = null;

    /**
     * Application Constructor
     */
    constructor() {
        _writeAddr = APP_FLASH_START_ADDR;
        _writeLen = 0;
        // Initialize ESP32 loader
        _initESPLoader();
        // Initialize library for communication with Imp-Agent
        _initMsngr();
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Create and initialize Messenger instance
     */
    function _initMsngr() {
        _msngr = Messenger();
        _msngr.on(APP_M_MSG_NAME.INFO, _onInfo.bindenv(this));
        _msngr.on(APP_M_MSG_NAME.DATA, _onData.bindenv(this));
        _msngr.on(APP_M_MSG_NAME.ESP_FINISH, _onESPInLoaderFinish.bindenv(this));
    }

    /**
     * Create and initialize ESP32 loader instance
     */
    function _initESPLoader() {
        _espLoader = ESP32Loader({
                                    "strappingPin1" : APP_STRAP_PIN1,
                                    "strappingPin2" : APP_STRAP_PIN2,
                                    "strappingPin3" : APP_STRAP_PIN3
                                 },
                                 APP_ESP_UART,
                                 APP_ESP_FLASH_PARAM,
                                 APP_SWITCH_PIN
                                );
    }

    /**
     * Handler for firmware info received from Imp-Agent
     *
     * @param {table} msg - Received message payload.
     *
     * @param customAck - Custom acknowledgment function.
     */
    function _onESPInLoaderFinish(msg, customAck) {
        local ack = customAck();

        if (_isActive) {
            ::info(format("Loading is active. Try again later."));
            return;
        }

        _espLoader.finish()
        .finally(function(resOrErr) {
            ::info(resOrErr);
            // TODO: Is it needed here?
            _isActive = false;
        }.bindenv(this));

        // TODO: Why do we send this string in the ACK?
        ack("Flash end reboot");
    }

    /**
     * Handler for firmware info received from Imp-Agent
     *
     * @param {table} msg - Received message payload.
     *        The fields:
     *          "fileName" : {string} - Firmware filename.
     *          "md5"      : {string} - Firmware MD5 (ASCII string - 32 bytes).
     *          "fileLen"  : {integer} - Firmware length.
     *          "offs"     : {integer} - Address offset.
     * @param customAck - Custom acknowledgment function.
     */
    function _onInfo(msg, customAck) {
        local ack = customAck();
        local data = msg.data;

        if (_isActive) {
            ::info(format("Load active. Try again later."));
            return;
        }

        // TODO: Should we reset some variables here? E.g., _writeLen

        _md5Sum = data.md5;
        ::info(format("Save MD5: %s", data.md5));
        _fwName = data.fileName;
        ::info(format("Firmware image name: %s", _fwName));
        _offset = data.offs;
        ::info(format("Firmware image offset: 0x%08X", _offset));
        _len = data.fileLen;
        ::info(format("Firmware image length: %d", _len));
        if (!_erase(data.fileLen)) {
            ::error(format("Erase failure."));
            return;
        }
        ::info("Start write to imp-device flash.");
        ack(data.fileName);
    }

    /**
     * Handler for load firmware command received from Imp-Agent
     *
     * @param {table} msg - Received message payload.
     * @param customAck - Custom acknowledgment function.
     */
    function _onData(msg, customAck) {
        local ack = customAck();
        local data = msg.data;

        if (_isActive) {
            ::info(format("Loading is active. Try again later."));
            return;
        }

        hardware.spiflash.enable();
        _write(data);
        hardware.spiflash.disable();

        _writeLen += data.len();
        ack(_writeLen);

        if (_writeLen < _len) {
            return;
        }

        ::info("Writing to the imp's flash finished. Loading to the ESP32 started.");
        _isActive = true;

        _espLoader.start()
        .then(function(res) {
            _espLoader.load(APP_FLASH_START_ADDR,
                            _offset,
                            _len,
                            _md5Sum)
            .finally(function(resOrErr) {
                ::info(resOrErr);
                _isActive = false;
                _writeAddr = APP_FLASH_START_ADDR;
                _writeLen = 0;
            }.bindenv(this));
        }.bindenv(this))
        .fail(function(err) {
            ::error(err);
            _isActive = false;
        }.bindenv(this));
    }

    /**
     * Write to the Imp-Device flash
     *
     * @param {blob} portion - Portion of firmware image.
     */
    function _write(portion) {
        local len = portion.len();
        hardware.spiflash.write(_writeAddr, portion);
        _writeAddr += len;
    }

    /**
     * Erase Imp-Device flash
     *
     * @param {integer} size - Erased size.
     *
     * @return {boolean} - true - erase success.
     */
    function _erase(size) {
        // TODO: Can be replaced with (size + APP_SECTOR_SIZE - 1) / APP_SECTOR_SIZE?
        local sectorCount = (size % APP_SECTOR_SIZE) == 0 ?
                            size / APP_SECTOR_SIZE :
                            (size + APP_SECTOR_SIZE) / APP_SECTOR_SIZE;
        if (APP_FLASH_START_ADDR + sectorCount * APP_SECTOR_SIZE > APP_FLASH_END_ADDR) {
            ::error(format("Erasing failed. Check erase size![0x%08X;0x%08X]. Sector size: 0x%08X",
                           APP_FLASH_START_ADDR,
                           APP_FLASH_END_ADDR,
                           APP_SECTOR_SIZE));
            return false;
        }

        ::info(format("Start erasing SPI flash from 0x%x to 0x%x",
                      APP_FLASH_START_ADDR,
                      (APP_FLASH_START_ADDR + sectorCount * APP_SECTOR_SIZE)));
        hardware.spiflash.enable();
        for (local addr = APP_FLASH_START_ADDR;
             addr < (APP_FLASH_START_ADDR + sectorCount * APP_SECTOR_SIZE);
             addr += APP_SECTOR_SIZE) {
            hardware.spiflash.erasesector(addr);
        }
        hardware.spiflash.disable();

        ::info("Erasing finished!");
        return true;
    }
}

// ---------------------------- THE MAIN CODE ---------------------------- //

::info("ESP32 loader example device start");
// Run the application
app <- Application();
