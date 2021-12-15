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
