//line 1 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/agent/Main.agent.nut"
#require "Promise.lib.nut:4.0.0"
#require "Messenger.lib.nut:0.2.0"

//line 1 "../shared/Version.shared.nut"
// Application Version
const APP_VERSION = "1.2.0";
//line 1 "../shared/Constants.shared.nut"
// Constants common for the imp-agent and the imp-device

// ReplayMessenger message names
enum APP_RM_MSG_NAME {
    DATA = "data",
    GNSS_ASSIST = "gnssAssist",
    LOCATION_CELL = "locationCell"
}

// Init latitude value (North Pole)
const INIT_LATITUDE = 90.0;

// Init longitude value (Greenwich)
const INIT_LONGITUDE = 0.0;
//line 1 "../shared/Logger/Logger.shared.nut"
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
        _logStg = null;
        server.error("Logger storage disabled. Set LOGGER_STORAGE_ENABLE parameter to true.");
    },

    /**
     * Gets a storage
     *
     * @return{Logger.IStorage | null} - Instance of the Logger.IStorage object or null.
     */
    function getStorage() {
        server.error("Logger storage disabled. Set LOGGER_STORAGE_ENABLE parameter to true.");
        return null;
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
        _logStgLvl     = LGR_LOG_LEVEL.INFO;
        _logStgEnabled = false;
        server.error("Logger storage disabled. Set LOGGER_STORAGE_ENABLE parameter to true.");
    },

    /**
     * Prints out logs that are stored in the log storage to the impcentral log.
     *
     * @param {integer} [num] - Maximum number of logs to print. If 0 - try to print out all stored logs.
     *                              Optional. Default: 0.
     *
     * @return {boolean} - True if successful, False otherwise.
     */

    function printStoredLogs(num = 0) {
        server.error("Logger storage disabled. Set LOGGER_STORAGE_ENABLE parameter to \"true\".");
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
    }
}

// Setup global variables:
// the logger should be used like the following: `::info("log text", "optional log source")`
::debug <- Logger.debug.bindenv(Logger);
::info  <- Logger.info.bindenv(Logger);
::error <- Logger.error.bindenv(Logger);

Logger.setLogLevelStr("INFO");

//line 2 "CloudClient.agent.nut"

// Communicates with the cloud.
//   - Sends data to the cloud using REST API
//   - Basic HTTP authentication is used
//   - No buffering, data is sent immediately

// Timeout for waiting for a response from the cloud, in seconds
// TODO - decide do we need it, how it correlates with RM ack timeout
const CLOUD_REST_API_TIMEOUT = 60;

// "Data is accepted" status code returned from the cloud
const CLOUD_REST_API_SUCCESS_CODE = 200;

// API endpoints
const CLOUD_REST_API_DATA_ENDPOINT = "/data";

class CloudClient {

    /**
    * Sends a message to the cloud
    *
    * @param {string} body - Data to send to the cloud
    *
    * @return {Promise} that:
    * - resolves if the cloud accepted the data
    * - rejects with an error if the operation failed
    */
    function send(body) {
        local headers = {
            "Content-Type" : "application/json",
            "Content-Length" : body.len(),
            "Authorization" : "Basic " + http.base64encode(__VARS.CLOUD_REST_API_USERNAME + ":" + __VARS.CLOUD_REST_API_PASSWORD)
        };
        local req = http.post(__VARS.CLOUD_REST_API_URL + CLOUD_REST_API_DATA_ENDPOINT, headers, body);

        return Promise(function(resolve, reject) {
            req.sendasync(function(resp) {
                if (resp.statuscode == CLOUD_REST_API_SUCCESS_CODE) {
                    resolve();
                } else {
                    reject(resp.statuscode);
                }
            }.bindenv(this),
            null,
            CLOUD_REST_API_TIMEOUT);
        }.bindenv(this));
    }
}

//line 2 "LocationAssistant.agent.nut"

// URL to request BG96 Assist data
const LA_BG96_ASSIST_DATA_URL = "http://xtrapath4.izatcloud.net/xtra3grc.bin";

// Google Maps Geolocation API URL
const LA_GOOGLE_MAPS_LOCATION_URL = "https://www.googleapis.com/geolocation/v1/geolocate?key=";

// Location Assistant class:
// - obtains GNSS Assist data for BG96
// - obtains the location by cell towers info using Google Maps Geolocation API
class LocationAssistant {

    /**
     * Obtains GNSS Assist data for BG96
     *
     * @return {Promise} that:
     * - resolves with BG96 Assist data if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function getGnssAssistData() {
        ::debug("Downloading BG96 assist data...", "LocationAssistant");
        // Set up an HTTP request to get the assist data
        local request = http.get(LA_BG96_ASSIST_DATA_URL);

        return Promise(function(resolve, reject) {
            request.sendasync(function(response) {
                if (response.statuscode == 200) {
                    local data = blob(response.body.len());
                    data.writestring(response.body);
                    resolve(data);
                } else {
                    reject("Unexpected response status code: " + response.statuscode);
                }
            }.bindenv(this));
        }.bindenv(this));
    }

    /**
     * Obtains the location by cell towers info using Google Maps Geolocation API
     *
     * @param {Table} cellInfo - table with cell towers info
     *
     * @return {Promise} that:
     * - resolves with the location info if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function getLocationByCellInfo(cellInfo) {
        ::debug("Requesting location from Google Geolocation API. Cell towers passed: " + cellInfo.cellTowers.len(), "LocationAssistant");

        // Set up an HTTP request to get the location
        local url = format("%s%s", LA_GOOGLE_MAPS_LOCATION_URL, __VARS.GOOGLE_MAPS_API_KEY);
        local headers = { "Content-Type" : "application/json" };
        local body = {
            "considerIp" : "false",
            "radioType"  : cellInfo.radioType,
            "cellTowers" : cellInfo.cellTowers
        };

        local request = http.post(url, headers, http.jsonencode(body));

        return Promise(function(resolve, reject) {
            request.sendasync(function(resp) {
                if (resp.statuscode == 200) {
                    try {
                        local parsed = http.jsondecode(resp.body);
                        resolve({
                            "accuracy" : parsed.accuracy,
                            "lat"      : parsed.location.lat,
                            "lon"      : parsed.location.lng,
                            "time"     : time()
                        });
                    } catch(e) {
                        reject("Response parsing error: " + e);
                    }
                } else {
                    reject("Unexpected response status code: " + resp.statuscode);
                }
            }.bindenv(this))
        }.bindenv(this));
    }
}

//line 9 "/Users/ragruslan/Dropbox/NoBitLost/Prog-X/nbl_gl_repo/src/agent/Main.agent.nut"

// Main application on Imp-Agent:
// - Forwards Data messages from Imp-Device to Cloud REST API
// - Obtains GNSS Assist data for BG96 from server and returns it to Imp-Device
// - Obtains the location by cell towers info using Google Maps Geolocation API
//   and returns it to Imp-Device

class Application {
    // Messenger instance
    _msngr = null;

    /**
     * Application Constructor
     */
    constructor() {
        ::info("Application Version: " + APP_VERSION);

        // Initialize library for communication with Imp-Device
        _initMsngr();
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Create and initialize Messenger instance
     */
    function _initMsngr() {
        _msngr = Messenger();
        _msngr.on(APP_RM_MSG_NAME.DATA, _onData.bindenv(this));
        _msngr.on(APP_RM_MSG_NAME.GNSS_ASSIST, _onGnssAssist.bindenv(this));
        _msngr.on(APP_RM_MSG_NAME.LOCATION_CELL, _onLocationCell.bindenv(this));
    }

    /**
     * Handler for Data received from Imp-Device
     */
    function _onData(msg, customAck) {
        ::debug("Data received from imp-device");

        local ack = customAck();
        local data = http.jsonencode(msg.data);

        CloudClient.send(data)
        .then(function(_) {
            ::info("Data has been successfully sent to the cloud: " + data);
            ack();
        }.bindenv(this), function(err) {
            ::error("Cloud reported an error while receiving data: " + err);
            ::error("The data caused this error: " + data)
            // Don't ACK the message if we couldn't send the data to the cloud.
            // This message will be saved on the device and re-sent later
        }.bindenv(this));
    }

    /**
     * Handler for GNSS Assist request received from Imp-Device
     */
    function _onGnssAssist(msg, customAck) {
        local ack = customAck();

        LocationAssistant.getGnssAssistData()
        .then(function(data) {
            ::info("BG96 Assist data downloaded");
            ack(data);
        }.bindenv(this), function(err) {
            ::error("Error during downloading BG96 Assist data: " + err);
            // Send `null` in reply to the request
            ack(null);
        }.bindenv(this));
    }

    /**
     * Handler for Location By Cell Info request received from Imp-Device
     */
    function _onLocationCell(msg, customAck) {
        local ack = customAck();

        LocationAssistant.getLocationByCellInfo(msg.data)
        .then(function(location) {
            ::info("Location obtained using Google Geolocation API");
            ack(location);
        }.bindenv(this), function(err) {
            ::error("Error during location obtaining using Google Geolocation API: " + err);
            // Send `null` in reply to the request
            ack(null);
        }.bindenv(this));
    }
}

// ---------------------------- THE MAIN CODE ---------------------------- //

// Set default log level
Logger.setLogLevel(LGR_LOG_LEVEL.INFO);

// Run the application
app <- Application();
