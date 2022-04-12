// Logger for "DEBUG", "INFO" and "ERROR" information.
// Prints out information to the standard impcentral log ("server.log").
// The supported data types: string, table. Other types may be printed out incorrectly.
// The logger should be used like the following: `::info("log text", "optional log source")`

// If the log storage is configured, logs that cannot be printed while imp-device is offline
// are stored in RAM or Flash and are printed out later, when imp-device becomes back online.

// Log levels
enum LGR_LOG_LEVEL {
    ERROR, // enables output from the ::error() method only - the "lowest" log level
    INFO,  // enables output from the ::error() and ::info() methods
    DEBUG  // enables output from from all methods - ::error(), ::info() and ::debug() - the "highest" log level
}

Logger <- {
    VERSION = "0.2.0",

    // Current Log level to display
    _logLevel = LGR_LOG_LEVEL.INFO,

    // Log level to save in the log storage
    _logStgLvl = LGR_LOG_LEVEL.INFO,

    // The instance of the logger.IStorage.
    // Each item is table:
    //      "multiRow" : {boolean} - If true the multi-line mode of log output is used, one-line mode otherwise
    //      "prefix" : {string} - String with a prefix part of the log
    //      "log" : {string} - String with the main part of the log
    _logStg = null,

    // If true the log storage is enabled, otherwise the log storage is disabled
    _logStgEnabled = false,

    // Output stream for logging using server.log()
    // Implements the Logger.IOutputStream interface
    _outStream = {
        write = function(msg) {
            return server.log(msg);
        }
    },

    /**
     * Logs DEBUG information
     *
     * @param {any type} obj - Data to log
     * @param {string} [src] - Name of the data source. Optional.
     * @param {boolean} [multiRow] - If true, then each LINE FEED symbol in the data log
     *          prints the following data on a new line. Applicable to string data logs.
     *          Optional. Default: false
     */
    function debug(obj, src = null, multiRow = false) {
        local saveLog = _logStgLvl >= LGR_LOG_LEVEL.DEBUG && _logStgEnabled && null != _logStg;
        (_logLevel >= LGR_LOG_LEVEL.DEBUG) && _log("DEBUG", obj, src, multiRow, saveLog);
    },

    /**
     * Logs INFO information
     *
     * @param {any type} obj - Data to log
     * @param {string} [src] - Name of the data source. Optional.
     * @param {boolean} [multiRow] - If true, then each LINE FEED symbol in the data log
     *          prints the following data on a new line. Applicable to string data logs.
     *          Optional. Default: false
     */
    function info(obj, src = null, multiRow = false) {
        local saveLog = _logStgLvl >= LGR_LOG_LEVEL.INFO && _logStgEnabled && null != _logStg;
        (_logLevel >= LGR_LOG_LEVEL.INFO) && _log("INFO", obj, src, multiRow, saveLog);
    },

    /**
     * Logs ERROR information
     *
     * @param {any type} obj - Data to log
     * @param {string} [src] - Name of the data source. Optional.
     * @param {boolean} [multiRow] - If true, then each LINE FEED symbol in the data log
     *          prints the following data on a new line. Applicable to string data logs.
     *          Optional. Default: false
     */
    function error(obj, src = null, multiRow = false) {
        local saveLog = _logStgLvl >= LGR_LOG_LEVEL.ERROR && _logStgEnabled && null != _logStg;
        (_logLevel >= LGR_LOG_LEVEL.ERROR) && _log("ERROR", obj, src, multiRow, saveLog);
    },

    /**
     * Sets Log output to the specified level.
     * If not specified, resets to the default.
     *
     * @param {enum} [level] - Log level (LGR_LOG_LEVEL), optional
     *          Default: LGR_LOG_LEVEL.INFO
     */
    function setLogLevel(level = LGR_LOG_LEVEL.INFO) {
        _logLevel = level;
    },

    /**
     * Sets Log output to the level specified by string.
     * Supported strings: "error", "info", "debug" - case insensitive.
     * If not specified or an unsupported string, resets to the default.
     *
     * @param {string} [level] - Log level case insensitive string ["error", "info", "debug"]
     *          By default and in case of an unsupported string: LGR_LOG_LEVEL.INFO
     */
    function setLogLevelStr(level = "info") {
        (null != level) && (_logLevel = _logLevelStrToEnum(level));
    },

    /**
     * Get current log level in string format.
     * Supported strings: "error", "info", "debug" - case insensitive.
     *
     * @return {string} - Log level string ["error", "info", "debug"]
     */
    function getLogLevelStr() {
        return _logLevelEnumToStr(_logLevel);
    },

    /**
     * Sets output stream
     *
     * @param {Logger.IOutputStream} iStream - instance of an object that implements the Logger.IOutputStreem interface
     */
    function setOutputStream(iStream) {
        if (Logger.IOutputStream == iStream.getclass().getbase()) {
            _outStream = iStream;
        } else {
            throw "The iStream object must implement the Logger.IOutputStream interface"
        }
    }

    /**
     * Sets a storage
     *
     * @param {Logger.IStorage} iStorage - The instance of an object that implements the Logger.IStorage interface
     */
    function setStorage(iStorage) {
@if LOGGER_STORAGE_ENABLE == "true"
        if (Logger.IStorage == iStorage.getclass().getbase()) {
            if (null == iStorage.type) {
                throw "The type property of the iStorage not initialized. See Logger.IStorage class description";
            }

            _logStg = iStorage;
        } else {
            throw "The iStorage object must implement the Logger.IStorage interface"
        }
@else
        _logStg = null;
        server.error("Logger storage disabled. Set LOGGER_STORAGE_ENABLE parameter to true.");
@endif
    },

    /**
     * Gets a storage
     *
     * @return{Logger.IStorage | null} - Instance of the Logger.IStorage object or null.
     */
    function getStorage() {
@if LOGGER_STORAGE_ENABLE == "true"
        return _logStg;
@else
        server.error("Logger storage disabled. Set LOGGER_STORAGE_ENABLE parameter to true.");
        return null;
@endif
    }

    /**
     * Enables/configures or disables log storage
     *
     * @param {boolean} enabled - If true the log storage is enabled, otherwise the log storage is disabled
     * @param {string} [level] - Log level to save in the storage: "error", "info", "debug". Optional. Default: "info".
     *                               If the specified level is "higher" than the current log level to display,
     *                               then the level to save is set equal to the current level to display.
     * @param {integer} [num] - Maximum number of logs to store. Optional. Default: 0.
     */
    function setLogStorageCfg(enabled, level = "info") {
@if LOGGER_STORAGE_ENABLE == "true"
        assert(null != _logStg);

        if (enabled) {
            local stgLvl = _logLevelStrToEnum(level);
            if (stgLvl > _logLevel) {
                _logStgLvl = _logLevel;
            } else {
                _logStgLvl = stgLvl;
            }
        } else {
            _logStgLvl = LGR_LOG_LEVEL.INFO;

            _logStg.clear();
        }
        _logStgEnabled = enabled;
@else
        _logStgLvl     = LGR_LOG_LEVEL.INFO;
        _logStgEnabled = false;
        server.error("Logger storage disabled. Set LOGGER_STORAGE_ENABLE parameter to true.");
@endif
    },

    /**
     * Prints out logs that are stored in the log storage to the impcentral log.
     *
     * @param {integer} [num] - Maximum number of logs to print. If 0 - try to print out all stored logs.
     *                              Optional. Default: 0.
     *
     * @return {boolean} - True if successful, False otherwise.
     */
@if LOGGER_STORAGE_ENABLE == "true"
    _printCallQueue = [ ],
    _printTId       = null,
@endif

    function printStoredLogs(num = 0) {
@if LOGGER_STORAGE_ENABLE == "true"
        assert(null != _logStg);

        local print;

        print = function(num) {
            local cntr   = 0;
            local logStg = _logStg;

            local logItem = function(item) {
                local srvErr   = 0;
                local multiRow = item.multiRow;
                local prefix   = item.prefix;
                local log      = item.log;

                if (multiRow) {
                    srvErr = _logMR(prefix, log);
                } else {
                    srvErr = _outStream.write(prefix + log);
                }

                return srvErr;
            };

            logStg.read(
                function(data, next) {
                    local keepGoing = true;
                    if (!num) {
                        if (logItem(data)) {
                            keepGoing = false;
                        }
                    } else {
                        if (cntr != num) {
                            if (!logItem(data)) {
                                cntr += 1;
                            } else {
                                keepGoing = false;
                            }
                        } else {
                            keepGoing = false;
                        }
                    }
                    next(keepGoing);
                }.bindenv(this),

                function(itemsQty) {
                    // server.log("The number of read items from the storage: " + itemsQty);
                    _printCallQueue.remove(0);
                    if (_printCallQueue.len()) {
                        // server.log("Process next job in the print queue... " + _printCallQueue[0]);
                        _printTId = imp.wakeup(0, function() {
                            print(_printCallQueue[0]);
                        }.bindenv(this));
                    } else {
                        // server.log("No jobs in the print queue. Finishing...");
                        _printTId = null;
                    }
                }.bindenv(this)
            );
        }.bindenv(this);

        _printCallQueue.append(num);

        if (null == _printTId) {
            _printTId = imp.wakeup(0, function() {
                print(_printCallQueue[0]);
            }.bindenv(this));
        }
@else
        server.error("Logger storage disabled. Set LOGGER_STORAGE_ENABLE parameter to \"true\".");
@endif
    },

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Forms and outputs a log message
     *
     * @param {string} levelName - Level name to log
     * @param {any type} obj - Data to log
     * @param {string} src - Name of the data source.
     * @param {boolean} multiRow - If true, then each LINE FEED symbol in the data log
     *          prints the following data on a new line. Applicable to string data logs.
     * @param {boolean} saveLog - If true, then if there is no connection,
     *          the log will be saved in the log storage for sending when the connection is restored.
     */
    function _log(levelName, obj, src, multiRow, saveLog) {
        local prefix = "[" + levelName + "]";
        src && (prefix += "[" + src + "]");
        prefix += " ";

        local objType = typeof(obj);
        local srvErr;
        local lg = "";

        if (objType == "table") {
            lg       = _tableToStr(obj);
            multiRow = true;
        } else {
            try {
                lg = obj.tostring();
            } catch(exp) {
                server.error("Exception during output log message: " + exp);
                return;
            }
        }

        if (multiRow) {
            srvErr = _logMR(prefix, lg);
        } else {
            srvErr = _outStream.write(prefix + lg);
        }

@if LOGGER_STORAGE_ENABLE == "true"
        local logStg = _logStg;

        if (saveLog && srvErr) {
            local fullPref = _getDateStr() + prefix;

            try {
                logStg.append({
                    "multiRow": multiRow,
                    "prefix"  : fullPref,
                    "log"     : lg
                });
            } catch (ex) {
                server.error("Can't save the log message. Reasone: " + ex);
                return;
            }
        }

        if (saveLog && !srvErr) {
            printStoredLogs();
        }
@endif
    },

    /**
     * Outputs a log message in multiRow mode
     *
     * @param {string} prefix - Prefix part of the log.
     * @param {string} str - Main part of the log.
     *
     * @return {integer} - 0 on success, or a _outStream.write() "Send Error Code" if it fails to output at least one line.
     */
    function _logMR(prefix, str) {
        local srvErr;
        local rows = split(str, "\n");

        srvErr = _outStream.write(prefix + rows[0]);
        if (srvErr) {
            return srvErr;
        }

        local tab = blob(prefix.len());
        for (local i = 0; i < prefix.len(); i++) {
            tab[i] = ' ';
        }
        tab = tab.tostring();

        for (local rowIdx = 1; rowIdx < rows.len(); rowIdx++) {
            srvErr = _outStream.write(tab + rows[rowIdx]);
            if (srvErr) {
                return srvErr;
            }
        }

        return srvErr;
    },

    /**
    * Converts table to string suitable for output in multiRow mode
    *
    * @param {table} tbl - The table
    * @param {integer} [level] - Table nesting level. For nested tables. Optional. Default: 0
    *
    * @return {string} - log suitable for output in multiRow mode.
    */
    function _tableToStr(tbl, level = 0) {
        local ret = "";
        local tab = "";

        for (local i = 0; i < level; i++) tab += "    ";

        ret += "{\n";
        local innerTab = tab + "    ";

        foreach (k, v in tbl) {
            if (typeof(v) == "table") {
                ret += innerTab + k + " : ";
                ret += _tableToStr(v, level + 1) + "\n";
            } else if (typeof(v) == "array") {
                local str = "[";

                foreach (v1 in v) {
                    str += v1 + ", ";
                }

                ret += innerTab + k + " : " + str + "],\n";
            } else if (v == null) {
                ret += innerTab + k + " : null,\n";
            } else {
                ret += format(innerTab + k + " : %s,", v.tostring()) + "\n";
            }
        }

        ret += tab + "}";
        return ret;
    },

@if LOGGER_STORAGE_ENABLE == "true"
    /**
     * Forms a string with the current date and time
     *
     * @return {string} - The current date and time.
     */
    function _getDateStr() {
        local dateTbl = date();
        return format("%u-%u-%uT%u:%u:%u ", dateTbl["year"], ++dateTbl["month"], dateTbl["day"], dateTbl["hour"], dateTbl["min"], dateTbl["sec"]);
    },
@endif

    /**
     * Converts log level specified by string to log level enum for Logger .
     * Supported strings: "error", "info", "debug" - case insensitive.
     * If not specified or an unsupported string, resets to the default.
     *
     * @param {string} [level] - Log level case insensitive string ["error", "info", "debug"]
     *          By default and in case of an unsupported string: LGR_LOG_LEVEL.INFO
     *
     * @return {enum} - Log level enum value for Logger
     */
    function _logLevelStrToEnum(levelStr) {
        local lgrLvl;
        switch (levelStr.tolower()) {
            case "error":
                lgrLvl = LGR_LOG_LEVEL.ERROR;
                break;
            case "info":
                lgrLvl = LGR_LOG_LEVEL.INFO;
                break;
            case "debug":
                lgrLvl = LGR_LOG_LEVEL.DEBUG;
                break;
            default:
                lgrLvl = LGR_LOG_LEVEL.INFO;
                break;
        }
        return lgrLvl;
    },

    /**
     * Converts log level to string.
     * Supported strings: "error", "info", "debug", "unknown".
     *
     * @param {enum} [level] - Log level enum value
     *
     * @return {string} - Log level case insensitive string ["error", "info", "debug", "unknown"]
     */
    function _logLevelEnumToStr(level) {
        local lgrLvlStr;
        switch (level) {
            case LGR_LOG_LEVEL.ERROR:
                lgrLvlStr = "error";
                break;
            case LGR_LOG_LEVEL.INFO:
                lgrLvlStr = "info";
                break;
            case LGR_LOG_LEVEL.DEBUG:
                lgrLvlStr = "debug";
                break;
            default:
                lgrLvlStr = "unknown";
                break;
        }
        return lgrLvlStr;
    }
}

// Setup global variables:
// the logger should be used like the following: `::info("log text", "optional log source")`
::debug <- Logger.debug.bindenv(Logger);
::info  <- Logger.info.bindenv(Logger);
::error <- Logger.error.bindenv(Logger);

Logger.setLogLevelStr("@{LOGGER_LEVEL}");

@if LOGGER_STORAGE_ENABLE == "true"
@include once __PATH__+"/storage/LoggerStorage.shared.nut"
@endif
