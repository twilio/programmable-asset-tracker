// Logger for "DEBUG", "INFO" and "ERROR" information.
// Prints out information to the standard impcentral log ("server.log").
// The supported data types: string, table. Other types may be printed out incorrectly.
// The logger should be used like the following: `::info("log text", "optional log source")`

// Log levels
enum LGR_LOG_LEVEL {
    ERROR, // enables output from the ::error() method only
    INFO,  // enables output from the ::error() and ::info() methods
    DEBUG  // enables output from from all methods - ::error(), ::info() and ::debug()
}

Logger <- {

    // Set the default Log level
    _logLevel = LGR_LOG_LEVEL.INFO,

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
        switch (level.tolower()) {
            case "error":
                _logLevel = LGR_LOG_LEVEL.ERROR;
                break;
            case "info":
                _logLevel = LGR_LOG_LEVEL.INFO;
                break;
            case "debug":
                _logLevel = LGR_LOG_LEVEL.DEBUG;
                break;
            default:
                _logLevel = LGR_LOG_LEVEL.INFO;
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
        (_logLevel >= LGR_LOG_LEVEL.DEBUG) && _log("DEBUG", obj, src, multiRow);
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
        (_logLevel >= LGR_LOG_LEVEL.INFO) && _log("INFO", obj, src, multiRow);
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
        (_logLevel >= LGR_LOG_LEVEL.ERROR) && _log("ERROR", obj, src, multiRow);
    },

    // -------------------- PRIVATE METHODS -------------------- //

    /**
    * Forms and outputs a log message
     *
     * @param {string} levelName - Level name to log
     * @param {any type} obj - Data to log
     * @param {string} [src] - Name of the data source.
     * @param {boolean} [multiRow] - If true, then each LINE FEED symbol in the data log
     *          prints the following data on a new line. Applicable to string data logs.
    */
    function _log(levelName, obj, src, multiRow) {
        local prefix = "[" + levelName + "]";
        src && (prefix += "[" + src + "]");
        prefix += " ";

        local objType = typeof(obj);

        if (typeof(obj) == "table") {
            foreach (v in _tableToStringArray(obj)) {
                server.log(prefix + v);
            }
        } else if (multiRow && objType == "string") {
            local rows = split(obj, "\n");
            server.log(prefix + rows[0]);

            local tab = blob(prefix.len());
            for (local i = 0; i < prefix.len(); i++) {
                tab[i] = ' ';
            }

            tab = tab.tostring();

            for (local rowIdx = 1; rowIdx < rows.len(); rowIdx++) {
                server.log(tab + rows[rowIdx]);
            }
        } else {
            server.log(prefix + obj);
        }
    }

    /**
    * Converts table to array of strings prepared for printing out
    *
    * @param {table} tbl - The table
    * @param {integer} [level] - Table nesting level. For nested tables. Default: 0
    *
    * @return {array} - string array.
    */
    function _tableToStringArray(tbl, level = 0) {
        local ret = [];
        local tab = "";

        for (local i = 0; i < level; i++) tab += "    ";

        ret.append(tab + "{");
        local innerTab = tab + "    ";

        foreach (k, v in tbl) {
            if (typeof(v) == "table") {
                ret.append(innerTab + k + " : ");
                ret.extend(_tableToStringArray(v, level + 1));
            } else if (typeof(v) == "array") {
                local str = "[";

                foreach (v1 in v) {
                    str += v1 + ", ";
                }

                ret.append(innerTab + k + " : " + str + "],");
            } else if (v == null) {
                ret.append(innerTab + k + " : null,");
            } else {
                ret.append(format(innerTab + k + " : %s,", v.tostring()));
            }
        }

        ret.append(tab + "}");
        return ret;
    }
}

// Setup global variables:
// the logger should be used like the following: `::info("log text", "optional log source")`
::debug <- Logger.debug.bindenv(Logger);
::info  <- Logger.info.bindenv(Logger);
::error <- Logger.error.bindenv(Logger);
