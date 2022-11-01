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

@include "github:electricimp/SpiFlashLogger/SPIFlashLogger.device.lib.nut@v2.2.0"
@include "github:electricimp/Serializer/Serializer.class.nut@v1.0.0"
@include once __PATH__+"/Logger.IStorage.shared.nut"

/**
 * SPI Flash Storage
 *
 */
class SpiFlashLoggerStorage extends Logger.IStorage {

    // SPIFlash interface object instance
    _flash = null;

    // SpiFlashlogger object instance
    _flashLogger = null;

    /**
     * Constructor
     *
     * @param {SPIFlash} flash - SPIFlash interface compatible object
     * @param {start} start - The first byte of flash used by the storage
     * @param {end} end - The last byte of flash used by the storage
     */
    function constructor(start = null, end = null, flash = null, erase = false)  {
        base.constructor(LOG_STORAGE_TYPE.FLASH);

        try {
            _flash = flash ? flash : hardware.spiflash;
        } catch (e) {
            throw "Missing requirement (hardware.spiflash). For more information see: ....";
        }

        end = (0 == end) ? null : end;

        _flashLogger = SPIFlashLogger(start, end, _flash);

        (true == erase) && _flashLogger.eraseAll();

@if BUILD_TYPE == "debug"
        _printInfo();
@endif
    }

    // -------------------- LOGGER STORAGE INTERFACE METHODS -------------------- //

    /**
     * This method adds the value passed as the method’s parameter to the end of the storage.
     */
    function append(value) {
        try {
            _flashLogger.write(value);
        } catch(ex) {
            throw ex;
        }
    }

    /**
     * This method removes every item from the storage.
     */
    function clear() {
        _flashLogger.eraseAll();
    }

    /**
     * Reads log from the storage
     */
    _readTId = null;

    function read(onItem, onFinish = null) {
        assert(null != onItem);

        local itemsQty;

        local read = function() {
            _flashLogger.read(
                function(data, address, next) {
                    local getNext = function(keepGoing = true) {
                        if (keepGoing) {
                            itemsQty += 1;
                            _flashLogger.erase(address);
                        }
                        next(keepGoing);
                    };
                    onItem(data, getNext.bindenv(this));
                }.bindenv(this),
                function() {
                    _readTId = null;

                    (null != onFinish) && onFinish(itemsQty);
                }.bindenv(this)
            )
        };

        if (null == _readTId) {
            _readTId  = imp.wakeup(0, read.bindenv(this));
            itemsQty = 0;
        }
    }

    // -------------------- PRIVATE METHODS -------------------- //

@if BUILD_TYPE == "debug"
    /**
    * Print generic information about flash storage
    */
    function _printInfo() {
        local flashInfo = _flashLogger.dimensions();
        server.log("The size of SPI flash: " + flashInfo.size);
        server.log("The first byte used by the logger: " + flashInfo.start);
        server.log("The last byte used by the logger: " + flashInfo.end);
    }
@endif
}
