@include once __PATH__+"/Logger.IStorage.shared.nut"

// Maximum number of characters in every log to save in the log storage
@if LOGGER_RAM_STG_MAX_LOG_LEN
const LGR_RAM_STG_MAX_LOG_LEN = @{LOGGER_RAM_STG_MAX_LOG_LEN};
@else
const LGR_RAM_STG_MAX_LOG_LEN = 250;
@endif

// Maximum number of items to save in the log storage
@if LOGGER_RAM_STG_MAX_ITEMS
const LGR_RAM_STG_MAX_ITEMS = @{LOGGER_RAM_STG_MAX_ITEMS};
@else
const LGR_RAM_STG_MAX_ITEMS = 50;
@endif


/**
 * RAM storage
 *
 */
class RamLoggerStorage extends Logger.IStorage {

    // Array for storing items in the storage
    _stg = null;

    // Maximum number of items to save in the log storage
    _maxNum = 0;

    /**
     * Constructor
     * @param {integer} [num] - Maximum number of logs to store. Optional. Default: 0.
     */
    constructor(num = LGR_RAM_STG_MAX_ITEMS) {
        base.constructor(LOG_STORAGE_TYPE.RAM);

        _maxNum = num;
        _stg    = [ ];
    }

    // -------------------- LOGGER STORAGE INTERFACE METHODS -------------------- //

    /**
     * This method adds the value passed as the method’s parameter to the end of the storage.
     *
     * @param{String} value - A message to store
     */
    function append(value) {
        if (value.len() >= LGR_RAM_STG_MAX_LOG_LEN) {
            throw "The log message is too long. Can't save the log message!";
        }

        if (_stg.len() >= _maxNum) {
            _stg.remove(0);
        }
        _stg.append(value);
    }

    /**
     * This method removes every item from the storage.
     */
    function clear() {
        _stg.clear();
    }

    /**
     * Reads log from the storage
     */
    _readTId = null;

    function read(onItem, onFinish = null) {
        assert(null != onItem);

        local itemsQty, sendItem, getNext, finish;

        finish = function() {
            _readTId  = null;

            (null != onFinish) && onFinish(itemsQty);
        };

        getNext = function(keepGoing = true) {
            if (!keepGoing || !_stg.len())
                return finish();

            itemsQty += 1;
            _stg.remove(0);

            imp.wakeup(0, sendItem.bindenv(this));
        };

        sendItem = function() {
            if (_stg.len()) {
                onItem(_stg[0], getNext.bindenv(this))
            } else {
                finish();
            }
        };

        if (null == _readTId) {
            _readTId  = imp.wakeup(0, sendItem.bindenv(this));
            itemsQty = 0;
        }
    }
}
