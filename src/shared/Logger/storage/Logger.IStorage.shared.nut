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

/**
 * Logger storage type
 */
enum LOG_STORAGE_TYPE {
    RAM,    // store logs in RAM
    FLASH   // store Logs in FLASH (imp-device only)
}

/**
 * Logger storage base class
 */
Logger.IStorage <- class {
    //  ------------ PUBLIC PROPERTIES  ----------- //

    // Log type
    type = null;


    //  ----------- PRIVATE PROPERTIES  ----------- //


    //  ----------- BASE CONSTRUCTOR  ------------ //
    /**
     * Must be called in the inherted class
     * base.constructor(...)
     *
     * @param(LOG_STORAGE_TYPE) type - Type of the storage
     *
     */
    constructor(type = null) {
        this.type    = type

@if BUILD_TYPE == "debug"
        _printStorageInfo();
@endif
    }

    //  ------ PUBLIC FUNCTIONS TO OVERRIDE  ------- //

    function append(item) { throw "The Append method must be implemented in an inherited class" }
    function clear() { throw "The Clear method must be implemented in an inherited class" }
    function read(onItem, onFinish) { throw "The Read method must be implemented in an inherited class" }


    //  --------- COMMON PUBLIC FUNCTIONS  --------- //

    function stgType() {
        return _typeToString(type);
    }

    //  ----------- PRIVATE FUNCTIONS  ------------ //

    /**
     *
     */
    function _typeToString(type) {
        local result;

        if (null == type) {
            result = "none"
        } else {
            switch(type) {
                case LOG_STORAGE_TYPE.RAM:
                    result = "ram";
                    break;
                case LOG_STORAGE_TYPE.FLASH:
                    result = "flash";
                    break;
                default:
                    result = "unknown";
                    break;
            }
        }
        return result;
    }

@if BUILD_TYPE == "debug"
    /**
    *
    */
    function _printStorageInfo() {
        server.log("Logger storage type: " + stgType());
    }
@endif
}
