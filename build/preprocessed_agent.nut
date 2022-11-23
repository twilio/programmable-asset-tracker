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

#require "rocky.agent.lib.nut:3.0.1"
#require "Promise.lib.nut:4.0.0"
#require "Messenger.lib.nut:0.2.0"
#require "UBloxAssistNow.agent.lib.nut:1.0.0"

// MIT License
//
// Copyright 2017-2021 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.

const GOOGLE_MAPS_WIFI_SIGNALS_ERROR        = "Insufficient wifi signals found";
const GOOGLE_MAPS_MISSING_REQ_PARAMS_ERROR  = "Location table must have keys: 'lat' and 'lng'";
const GOOGLE_MAPS_UNEXPECTED_RESP_ERROR     = "Unexpected response from Google";
const GOOGLE_MAPS_LIMIT_EXCEEDED_ERROR      = "You have exceeded your daily limit";
const GOOGLE_MAPS_INVALID_KEY_ERROR         = "Your Google Maps Geolocation API key is not valid or the request body is not valid JSON";
const GOOGLE_MAPS_LOCATION_NOT_FOUND_ERROR  = "Your API request was valid, but no results were returned";
const GOOGLE_MAPS_NO_PROMISE_LIB_ERROR      = "If no callback passed, the Promise library is required";

class GoogleMaps {

    static VERSION = "1.1.0";

    static LOCATION_URL = "https://www.googleapis.com/geolocation/v1/geolocate?key=";
    static TIMEZONE_URL = "https://maps.googleapis.com/maps/api/timezone/json?";

    _apiKey = null;

    constructor(apiKey) {
        _apiKey = apiKey;
    }

    function getGeolocation(data, cb = null) {
        // We assume that if data is an array, then it contains WiFi networks.
        // NOTE: This is for the backward compatibility with v1.0.x
        if (typeof data == "array") {
            data = {
                "wifiAccessPoints": data
            };
        }

        local body = clone data;

        if (!("considerIp" in body)) {
            body.considerIp <- false;
        }

        if ("wifiAccessPoints" in data) {
            if (!("cellTowers" in data) && data.wifiAccessPoints.len() < 2) {
                if (cb) {
                    imp.wakeup(0, @() cb(GOOGLE_MAPS_WIFI_SIGNALS_ERROR, null));
                    return;
                } else {
                    return Promise.reject(GOOGLE_MAPS_WIFI_SIGNALS_ERROR);
                }
            }

            local wifis = [];

            foreach (wifi in data.wifiAccessPoints) {
                wifis.append({
                    "macAddress": _addColons(wifi.bssid),
                    "signalStrength": wifi.rssi,
                    "channel" : wifi.channel
                });
            }

            body.wifiAccessPoints <- wifis;
        }

        // Build request
        local url = format("%s%s", LOCATION_URL, _apiKey);
        local headers = {"Content-Type" : "application/json"};
        local request = http.post(url, headers, http.jsonencode(body));

        return _processRequest(request, _locationRespHandler, cb, data);
    }

    function getTimezone(location, cb = null) {
        // Make sure we have the parameters we need to make request
        if (!("lat" in location && "lng" in location)) {
            if (cb) {
                cb(GOOGLE_MAPS_MISSING_REQ_PARAMS_ERROR, null);
                return;
            } else {
                return Promise.reject(GOOGLE_MAPS_MISSING_REQ_PARAMS_ERROR);
            }
        }

        local url = format("%slocation=%f,%f&timestamp=%d&key=%s", TIMEZONE_URL, location.lat, location.lng, time(), _apiKey);
        local request = http.get(url, {});

        return _processRequest(request, _timezoneRespHandler, cb);
    }

    // additionalData - an optional parameter which will be passed to respHandler once the response has been received
    function _processRequest(request, respHandler, cb, additionalData = null) {
        if (!cb) {
            if (!("Promise" in getroottable())) {
                throw GOOGLE_MAPS_NO_PROMISE_LIB_ERROR;
            }

            return Promise(function(resolve, reject) {
                cb = function(err, resp) {
                    err ? reject(err) : resolve(resp);
                }.bindenv(this);

                request.sendasync(function(res) {
                    respHandler(res, cb, additionalData);
                }.bindenv(this));
            }.bindenv(this));
        }

        request.sendasync(function(res) {
            respHandler(res, cb, additionalData);
        }.bindenv(this));
    }

    // _ - unused parameter. Declared only for unification with the other response handler
    function _timezoneRespHandler(res, cb, _ = null) {
        local body;
        local err = null;

        try {
            body = http.jsondecode(res.body);
        } catch(e) {
            imp.wakeup(0, function() { cb(e, res); }.bindenv(this));
            return;
        }

        if ("status" in body) {
            if (body.status == "OK") {
                // Success
                local t = time() + body.rawOffset + body.dstOffset;
                local d = date(t);
                body.time <- t;
                body.date <- d;
                body.dateStr <- format("%04d-%02d-%02d %02d:%02d:%02d", d.year, d.month+1, d.day, d.hour, d.min, d.sec)
                body.gmtOffset <- body.rawOffset + body.dstOffset;
                body.gmtOffsetStr <- format("GMT%s%d", body.gmtOffset < 0 ? "-" : "+", math.abs(body.gmtOffset / 3600));
            } else {
                if ("errorMessage" in body) {
                    err = body.status + ": " + body.errorMessage;
                } else {
                    err = body.status;
                }
            }
        } else {
            err = res.statuscode + ": " + GOOGLE_MAPS_UNEXPECTED_RESP_ERROR;
        }

        // Pass err/response to callback
        imp.wakeup(0, function() {
            (err) ?  cb(err, res) : cb(err, body);
        }.bindenv(this));
    }

    // Process location HTTP response
    function _locationRespHandler(res, cb, reqData) {
        local body;
        local err = null;

        try {
            body = http.jsondecode(res.body);
        } catch(e) {
            imp.wakeup(0, function() { cb(e, res); }.bindenv(this));
            return;
        }

        local statuscode = res.statuscode;
        switch(statuscode) {
            case 200:
                if ("location" in body) {
                    res = body;
                } else {
                    err = GOOGLE_MAPS_LOCATION_NOT_FOUND_ERROR;
                }
                break;
            case 400:
                err = GOOGLE_MAPS_INVALID_KEY_ERROR;
                break;
            case 403:
                err = GOOGLE_MAPS_LIMIT_EXCEEDED_ERROR;
                break;
            case 404:
                err = GOOGLE_MAPS_LOCATION_NOT_FOUND_ERROR;
                break;
            case 429:
                // Too many requests try again in a second
                imp.wakeup(1, function() { getGeolocation(reqData, cb); }.bindenv(this));
                return;
            default:
                if ("message" in body) {
                    // Return Google's error message
                    err = body.message;
                } else {
                    // Pass generic error and response so user can handle error
                    err = GOOGLE_MAPS_UNEXPECTED_RESP_ERROR;
                }
        }

        imp.wakeup(0, function() { cb(err, res); }.bindenv(this));
    }

    // Format bssids for Google
    function _addColons(bssid) {
        // Format a WLAN basestation MAC for transmission to Google
        local result = bssid.slice(0, 2);
        for (local i = 2 ; i < 12 ; i += 2) {
            result = result + ":" + bssid.slice(i, i + 2)
        }
        return result.toupper();
    }
}
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

// Application Version
const APP_VERSION = "3.1.2";
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

// Constants common for the imp-agent and the imp-device

// ReplayMessenger message names
enum APP_RM_MSG_NAME {
    DATA = "data",
    GNSS_ASSIST = "gnssAssist",
    LOCATION_CELL_WIFI = "locationCellAndWiFi",
    CFG = "cfg"
}

// Init latitude value (North Pole)
const INIT_LATITUDE = 90.0;

// Init longitude value (Greenwich)
const INIT_LONGITUDE = 0.0;
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

Logger.setLogLevelStr("INFO");

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


// "Data is accepted" status code returned from the cloud
const CLOUD_REST_API_SUCCESS_CODE = 200;

// API endpoints
const CLOUD_REST_API_DATA_ENDPOINT = "/data";

// Communicates with the cloud.
//   - Sends data to the cloud using REST API
//   - Basic HTTP authentication is used
//   - No buffering, data is sent immediately and only once
class CloudClient {
    // Cloud's URL
    _url = null;
    // Username for Basic auth
    _user = null;
    // Password for Basic auth
    _pass = null;

    /**
     * Constructor for Cloud Client Class
     *
     * @param {string} url - Cloud's URL
     * @param {string} user - Username for Basic auth
     * @param {string} pass - Password  for Basic auth
     */
    constructor(url, user, pass) {
        _url = url;
        _user = user;
        _pass = pass;
    }

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
            "Authorization" : "Basic " + http.base64encode(_user + ":" + _pass)
        };
        local req = http.post(_url + CLOUD_REST_API_DATA_ENDPOINT, headers, body);

        return Promise(function(resolve, reject) {
            req.sendasync(function(resp) {
                if (resp.statuscode == CLOUD_REST_API_SUCCESS_CODE) {
                    resolve();
                } else {
                    reject(resp.statuscode);
                }
            }.bindenv(this));
        }.bindenv(this));
    }
}

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


// Google Maps Geolocation API URL
const LA_GOOGLE_MAPS_LOCATION_URL = "https://www.googleapis.com/geolocation/v1/geolocate?key=";

// Location Assistant class:
// - obtains GNSS Assist data for u-blox
// - obtains the location by cell towers info using Google Maps Geolocation API
class LocationAssistant {
    // U-Blox Assist Now instance
    _ubloxAssistNow = null;
    // Google Maps instance
    _gmaps = null;

    /**
     * Set tokens for u-blox Assist Now and Google Geolocation API
     *
     * @param {string} [ubloxAssistToken] - U-blox Assist Now token
     * @param {string} [gmapsKey] - U-blox Assist Now token
     */
    function setTokens(ubloxAssistToken = null, gmapsKey = null) {
        ubloxAssistToken && (_ubloxAssistNow = UBloxAssistNow(ubloxAssistToken));
        gmapsKey         && (_gmaps = GoogleMaps(gmapsKey));
    }

    /**
     * Obtain GNSS Assist data for u-blox
     *
     * @return {Promise} that:
     * - resolves with u-blox assist data if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function getGnssAssistData() {
        if (!_ubloxAssistNow) {
            return Promise.reject("No u-blox Assist Now token set");
        }

        ::debug("Downloading u-blox assist data...", "LocationAssistant");

        local assistOfflineParams = {
            "gnss"   : ["gps", "glo"],
            "period" : 1,
            "days"   : 3
        };

        return Promise(function(resolve, reject) {
            local onDone = function(error, resp) {
                if (error != null) {
                    return reject(error);
                }

                local assistData = _ubloxAssistNow.getOfflineMsgByDate(resp);

                if (assistData.len() == 0) {
                    return reject("No u-blox offline assist data received");
                }

                resolve(assistData);
            }.bindenv(this);

            _ubloxAssistNow.requestOffline(assistOfflineParams, onDone.bindenv(this));
        }.bindenv(this));
    }

    /**
     * Obtain the location by cell towers and WiFi networks using Google Maps Geolocation API
     *
     * @param {table} locationData - Scanned cell towers and WiFi networks
     *
     * @return {Promise} that:
     * - resolves with the location info if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function getLocationByCellInfoAndWiFi(locationData) {
        if (!_gmaps) {
            return Promise.reject("No Google Geolocation API key set");
        }

        ::debug("Requesting location from Google Geolocation API..", "LocationAssistant");
        ::debug(http.jsonencode(locationData));

        return _gmaps.getGeolocation(locationData);
    }
}

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

// Supported configuration JSON format/scheme version
const CFG_SCHEME_VERSION = "1.1";

// Configuration safeguard/validation constants:
// NOTE: These constants may need some adjustments

// "connectingPeriod"
// How often the tracker connects to network (minimal value), in seconds.
const CFG_CONNECTING_SAFEGUARD_MIN = 10.0;
// How often the tracker connects to network (maximal value), in seconds.
const CFG_CONNECTING_SAFEGUARD_MAX = 360000.0;

// "readingPeriod"
// How often the tracker polls various data (minimal value), in seconds.
const CFG_READING_SAFEGUARD_MIN = 10.0;
// How often the tracker polls various data (maximal value), in seconds.
const CFG_READING_SAFEGUARD_MAX = 360000.0;

// "locReadingPeriod"
// How often the tracker obtains a location (minimal value), in seconds.
const CFG_LOC_READING_SAFEGUARD_MIN = 10.0;
// How often the tracker obtains a location (maximal value), in seconds.
const CFG_LOC_READING_SAFEGUARD_MAX = 360000.0;

// "motionMonitoring":

// "movementAccMin", "movementAccMax"
// Minimal acceleration for movement detection, in g.
const CFG_MOVEMENT_ACC_SAFEGUARD_MIN = 0.1;
// Maximal acceleration for movement detection, in g.
const CFG_MOVEMENT_ACC_SAFEGUARD_MAX = 4.0;

// "movementAccDur"
// Minimal movement acceleration duration, in seconds.
const CFG_MOVEMENT_ACC_DURATION_SAFEGUARD_MIN = 0.01;
// Maximal movement acceleration duration, in seconds.
const CFG_MOVEMENT_ACC_DURATION_SAFEGUARD_MAX = 1.27;

// "motionTime"
// Minimal motion time value, in seconds.
const CFG_MOTION_TIME_SAFEGUARD_MIN = 1.0;
// Maximal motion time value, in seconds.
const CFG_MOTION_TIME_SAFEGUARD_MAX = 3600.0;

// "motionVelocity"
// Minimal motion velocity, in meter per second.
const CFG_MOTION_VEL_SAFEGUARD_MIN = 0.1;
// Maximal motion velocity, in meter per second.
const CFG_MOTION_VEL_SAFEGUARD_MAX = 20.0;

// "motionDistance"
// Minimal distance to determine motion detection condition, in meters.
const CFG_MOTION_DIST_SAFEGUARD_MIN = 0.1;
// Maximal distance to determine motion detection condition, in meters.
const CFG_MOTION_DIST_SAFEGUARD_MAX = 1000.0;
// Valid motion distance value, outside of the range
const CFG_MOTION_DIST_FIXED_VAL = 0.0;

// "motionStopTimeout"
// Minimal timeout to confirm motion stop, in seconds.
const CFG_MOTION_STOP_SAFEGUARD_MIN = 10.0;
// Maximal timeout to confirm motion stop, in seconds.
const CFG_MOTION_STOP_SAFEGUARD_MAX = 3600.0;

// "alerts":

// "shockDetected"
// Minimal shock acceleration alert threshold, in g.
// 1 LSb = 16 mg @ FS = 2 g
// 1 LSb = 32 mg @ FS = 4 g
// 1 LSb = 62 mg @ FS = 8 g
// 1 LSb = 186 mg @ FS = 16 g
const CFG_SHOCK_ACC_SAFEGUARD_MIN = 0.016;
// Maximal shock acceleration alert threshold, in g.
const CFG_SHOCK_ACC_SAFEGUARD_MAX = 16.0;

// "temperatureLow", "temperatureHigh"
// Minimal temperature value, in degrees Celsius.
const CFG_TEMPERATURE_THR_SAFEGUARD_MIN = -90.0;
// Maximal temperature value, in degrees Celsius.
const CFG_TEMPERATURE_THR_SAFEGUARD_MAX = 90.0;
// Minimal temperature hysteresis, in degrees Celsius.
const CFG_TEMPERATURE_HYST_SAFEGUARD_MIN = 0.1;
// Maximal temperature hysteresis, in degrees Celsius.
const CFG_TEMPERATURE_HYST_SAFEGUARD_MAX = 10.0;

// "batteryLow"
// Minimal charge level, in percent.
const CFG_CHARGE_LEVEL_THR_SAFEGUARD_MIN = 0.0;
// Maximal charge level, in percent.
const CFG_CHARGE_LEVEL_THR_SAFEGUARD_MAX = 100.0;

// "tamperingDetected"
// Minimum polling period, in seconds.
const CFG_TAMPERING_POLL_PERIOD_SAFEGUARD_MIN = 0.1;
// Maximum polling period, in seconds.
const CFG_TAMPERING_POLL_PERIOD_SAFEGUARD_MAX = 86400.0;

// other:

// "lng"
// Minimal value of Earth longitude, in degrees.
const CFG_LONGITUDE_SAFEGUARD_MIN = -180.0;
// Maximal value of Earth longitude, in degrees.
const CFG_LONGITUDE_SAFEGUARD_MAX = 180.0;

// "lat"
// Minimal value of Earth latitude, in degrees.
const CFG_LATITUDE_SAFEGUARD_MIN = -90.0;
// Maximal value of Earth latitude, in degrees.
const CFG_LATITUDE_SAFEGUARD_MAX = 90.0;

// "radius"
// Maximal geofence radius - the Earth radius, in meters.
const CFG_GEOFENCE_RADIUS_SAFEGUARD_MIN = 0.0;
// Maximal geofence radius - the Earth radius, in meters.
const CFG_GEOFENCE_RADIUS_SAFEGUARD_MAX = 6371009.0;

// "after"
// Minimal start time of repossesion, Unix timestamp
// 31.03.2020 12:53:04
const CFG_MIN_TIMESTAMP = 1585666384;
// Maximal start time of repossesion, Unix timestamp
// 17.04.2035 18:48:49
const CFG_MAX_TIMESTAMP = 2060448529;

// "duration"
// Minimum SIM update duration, in seconds.
const CFG_SIM_UPDATE_DURATION_SAFEGUARD_MIN = 5.0;
// Maximum SIM update duration, in seconds.
const CFG_SIM_UPDATE_DURATION_SAFEGUARD_MAX = 300.0;

// Maximal value of iBeacon minor, major
const CFG_BEACON_MINOR_MAJOR_VAL_MAX = 65535;

// Minimal length of a string.
const CFG_STRING_LENGTH_MIN = 1;
// Maximal length of a string.
const CFG_STRING_LENGTH_MAX = 50;

// validation rules for coordinates
coordValidationRules <- [{"name":"lng",
                          "required":false,
                          "validationType":"integer|float",
                          "lowLim":CFG_LONGITUDE_SAFEGUARD_MIN,
                          "highLim":CFG_LONGITUDE_SAFEGUARD_MAX,
                          "dependencies":["lat"]},
                         {"name":"lat",
                          "required":false,
                          "validationType":"integer|float",
                          "lowLim":CFG_LATITUDE_SAFEGUARD_MIN,
                          "highLim":CFG_LATITUDE_SAFEGUARD_MAX,
                          "dependencies":["lng"]}];

/**
 * Validation of the full or partial configuration.
 *
 * @param {table} msg - Configuration table.
 *
 * @return {null | string} null - validation success, otherwise error string.
 */
function validateCfg(msg) {
    // validate agent configuration
    if ("agentConfiguration" in msg) {
        local agentCfg = msg.agentConfiguration;
        if ("debug" in agentCfg) {
            local debugParam = agentCfg.debug;
            local validLogLevRes = _validateLogLevel(debugParam);
            if (validLogLevRes != null) return validLogLevRes;
        }
    }

    // validate configuration
    if ("configuration" in msg) {
        local conf = msg.configuration;
        local validIndFieldRes = _validateIndividualField(conf);
        if (validIndFieldRes != null) return validIndFieldRes;
        // validate device log level
        if ("debug" in conf) {
            local debugParam = conf.debug;
            local validLogLevRes = _validateLogLevel(debugParam);
            if (validLogLevRes != null) return validLogLevRes;
        }
        // validate alerts
        if ("alerts" in conf) {
            local alerts = conf.alerts;
            local validAlertsRes = _validateAlerts(alerts);
            if (validAlertsRes != null) return validAlertsRes;
        }
        // validate location tracking
        if ("locationTracking" in conf) {
            local tracking = conf.locationTracking;
            local validLocTrackRes = _validateLocTracking(tracking);
            if (validLocTrackRes != null) return validLocTrackRes;
        }
        // validate SIM update
        if ("simUpdate" in conf) {
            local simUpdate = conf.simUpdate;
            local validSimUpdateRes = _validateSimUpdate(simUpdate);
            if (validSimUpdateRes != null) return validSimUpdateRes;
        }
    }

    return null;
}

/**
 * Parameters validation
 *
 * @param {table} rules - The validation rules table.
 *        The table fields:
 *          "name": {string} - Parameter name.
 *          "required": {bool} - Availability in the configuration parameters.
 *          "validationType": {string} - Allowed parameter type(s) ("float", "string", "integer").
 *                                       Several types can be specified using "|" as a separator.
 *          "lowLim": {float, integer} - Parameter minimum value (for float and integer).
 *          "highLim": {float, integer} - Parameter maximum value (for float and integer).
 *          "minLen": {integer} - Minimal length of the string parameter.
 *          "maxLen": {integer} - Maximal length of the string parameter.
 *          "minTimeStamp": {string} - UNIX timestamp string.
 *          "maxTimeStamp": {string} - UNIX timestamp string.
 *          "fixedValues": {array} - Permissible fixed value array (not in [lowLim, highLim]).
 *          "dependencies":{array} - Fields specified together only.
 * @param {table} cfgGroup - Table with the configuration parameters.
 *
 * @return {null | string} null - validation success, otherwise error string.
 */
function _rulesCheck(rules, cfgGroup) {
    foreach (rule in rules) {
        local fieldNotExist = true;
        foreach (fieldName, field in cfgGroup) {
            if (rule.name == fieldName) {
                fieldNotExist = false;
                local allowedTypes = split(rule.validationType, "|");
                if (allowedTypes.find(typeof(field)) == null) {
                    return ("Field: "  + fieldName + " - type mismatch");
                }
                if ("lowLim" in rule && "highLim" in rule) {
                    if (field < rule.lowLim || field > rule.highLim) {
                        if ("fixedValues" in rule) {
                            local notFound = true;
                            foreach (fixedValue in rule.fixedValues) {
                                if (field == fixedValue) {
                                    notFound = false;
                                    break;
                                }
                            }
                            if (notFound) {
                                return ("Field: "  + fieldName + " - value not in range");
                            }
                        } else {
                            return ("Field: "  + fieldName + " - value not in range");
                        }
                    }
                }
                if ("minLen" in rule && "maxLen" in rule) {
                    local fieldLen = field.len();
                    if (fieldLen < rule.minLen || fieldLen > rule.maxLen) {
                        return ("Field: "  + fieldName + " - length not in range");
                    }
                }
                if ("minTimeStamp" in rule) {
                    if (field.tointeger() < rule.minTimeStamp.tointeger()) {
                        return ("Field: "  + fieldName + " - time not in range");
                    }
                }
                if ("maxTimeStamp" in rule) {
                    if (field.tointeger() > rule.maxTimeStamp.tointeger()) {
                        return ("Field: "  + fieldName + " - time not in range");
                    }
                }
            }
        }
        if ("dependencies" in rule) {
            foreach (depEl in rule.dependencies) {
                local notFound = true;
                foreach (fieldName, field in cfgGroup) {
                    if (depEl == fieldName) {
                        notFound = false;
                        break;
                    }
                }
                if (notFound) {
                    return ("Specified together only: " + depEl);
                }
            }
        }
        if (rule.required && fieldNotExist) {
            return ("Field: "  + rule.name + " - not exist");
        }
    }

    return null;
}

/**
 * Log level validation
 *
 * @param {table} logLevels - Table with the agent log level value.
 *        The table fields:
 *          "logLevel" : {string} Log level ("ERROR", "INFO", "DEBUG")
 *
 * @return {null | string} null - validation success, otherwise error string.
 */
function _validateLogLevel(logLevels) {
    if (!("logLevel" in logLevels)) {
        return null;
    }

    local logLevel = logLevels.logLevel;

    switch (logLevel) {
        case "DEBUG":
        case "INFO":
        case "ERROR":
            return null;
        default:
            return "Unknown log level";
    }
}

/**
 * Validation of individual fields.
 *
 * @param {table} conf - Configuration table.
 *
 * @return {null | string} null - Parameters are correct, otherwise error string.
 */
function _validateIndividualField(conf) {
    local validationRules = [];
    validationRules.append({"name":"connectingPeriod",
                            "required":false,
                            "validationType":"integer|float",
                            "lowLim":CFG_CONNECTING_SAFEGUARD_MIN,
                            "highLim":CFG_CONNECTING_SAFEGUARD_MAX});
    validationRules.append({"name":"readingPeriod",
                            "required":false,
                            "validationType":"integer|float",
                            "lowLim":CFG_READING_SAFEGUARD_MIN,
                            "highLim":CFG_READING_SAFEGUARD_MAX});
    validationRules.append({"name":"updateId",
                            "required":true,
                            "validationType":"string",
                            "minLen":CFG_STRING_LENGTH_MIN,
                            "maxLen":CFG_STRING_LENGTH_MAX});
    local rulesCheckRes = _rulesCheck(validationRules, conf);
    if (rulesCheckRes != null) return rulesCheckRes;

    return null;
}

/**
 * Validation of the alert parameters.
 *
 * @param {table} alerts - The alerts configuration table.
 *
 * @return {null | string} null - validation success, otherwise error string.
 */
function _validateAlerts(alerts) {
    foreach (alertName, alert in alerts) {
        local validationRules = [];
        // check enable field
        local checkEnableRes = _checkEnableField(alert);
        if (checkEnableRes != null) return checkEnableRes;
        // check other fields
        switch (alertName) {
            case "batteryLow":
                // charge level [0;100] %
                validationRules.append({"name":"threshold",
                                        "required":false,
                                        "validationType":"integer|float",
                                        "lowLim":CFG_CHARGE_LEVEL_THR_SAFEGUARD_MIN,
                                        "highLim":CFG_CHARGE_LEVEL_THR_SAFEGUARD_MAX});
                break;
            case "temperatureLow":
            case "temperatureHigh":
                // industrial temperature range
                validationRules.append({"name":"threshold",
                                        "required":false,
                                        "validationType":"integer|float",
                                        "lowLim":CFG_TEMPERATURE_THR_SAFEGUARD_MIN,
                                        "highLim":CFG_TEMPERATURE_THR_SAFEGUARD_MAX});
                validationRules.append({"name":"hysteresis",
                                        "required":false,
                                        "validationType":"integer|float",
                                        "lowLim":CFG_TEMPERATURE_HYST_SAFEGUARD_MIN,
                                        "highLim":CFG_TEMPERATURE_HYST_SAFEGUARD_MAX});
                break;
            case "shockDetected":
                // LIS2DH12 maximum shock threshold - 16 g
                validationRules.append({"name":"threshold",
                                        "required":false,
                                        "validationType":"integer|float",
                                        "lowLim":CFG_SHOCK_ACC_SAFEGUARD_MIN,
                                        "highLim":CFG_SHOCK_ACC_SAFEGUARD_MAX});
                break;
            case "tamperingDetected":
                validationRules.append({"name":"pollingPeriod",
                                        "required":false,
                                        "validationType":"integer|float",
                                        "lowLim":CFG_TAMPERING_POLL_PERIOD_SAFEGUARD_MIN,
                                        "highLim":CFG_TAMPERING_POLL_PERIOD_SAFEGUARD_MAX});
            default:
                break;
        }
        // rules checking
        local rulesCheckRes = _rulesCheck(validationRules, alert);
        if (rulesCheckRes != null) return rulesCheckRes;
    }
    // check low < high temperature
    if ("temperatureLow" in alerts &&
        "temperatureHigh" in alerts) {
        if ("threshold" in alerts.temperatureLow &&
            "threshold" in alerts.temperatureHigh) {
            if (alerts.temperatureLow.threshold >=
                alerts.temperatureHigh.threshold) {
                return "Temperature low threshold >= high threshold";
            }
        }
    }
    return null;
}

/**
 * Validation of the location tracking configuration block.
 *
 * @param {table} locTracking - Location tracking configuration table.
 *
 * @return {null | string} null - validation success, otherwise error string.
 */
function _validateLocTracking(locTracking) {
    local rulesCheckRes = null;
    local checkEnableRes = null;
    if ("locReadingPeriod" in locTracking) {
        local validationRules = [];
        validationRules.append({"name":"locReadingPeriod",
                                "required":false,
                                "validationType":"integer|float",
                                "lowLim":CFG_LOC_READING_SAFEGUARD_MIN,
                                "highLim":CFG_LOC_READING_SAFEGUARD_MAX});
        rulesCheckRes = _rulesCheck(validationRules, locTracking);
        if (rulesCheckRes != null) return rulesCheckRes;
    }
    if ("alwaysOn" in locTracking) {
        local validationRules = [];
        validationRules.append({"name":"alwaysOn",
                                "required":false,
                                "validationType":"bool"});
        rulesCheckRes = _rulesCheck(validationRules, locTracking);
        if (rulesCheckRes != null) return rulesCheckRes;
    }
    // validate motion monitoring configuration
    if ("motionMonitoring" in locTracking) {
        local validationRules = [];
        local motionMon = locTracking.motionMonitoring;
        // check enable field
        checkEnableRes = _checkEnableField(motionMon);
        if (checkEnableRes != null) return checkEnableRes;
        validationRules.append({"name":"movementAccMin",
                                "required":false,
                                "validationType":"integer|float",
                                "lowLim":CFG_MOVEMENT_ACC_SAFEGUARD_MIN,
                                "highLim":CFG_MOVEMENT_ACC_SAFEGUARD_MAX,
                                "dependencies":["movementAccMax"]});
        validationRules.append({"name":"movementAccMax",
                                "required":false,
                                "validationType":"integer|float",
                                "lowLim":CFG_MOVEMENT_ACC_SAFEGUARD_MIN,
                                "highLim":CFG_MOVEMENT_ACC_SAFEGUARD_MAX,
                                "dependencies":["movementAccMin"]});
        // min 1/ODR (current 100 Hz), max INT1_DURATION - 127/ODR
        validationRules.append({"name":"movementAccDur",
                                "required":false,
                                "validationType":"integer|float",
                                "lowLim":CFG_MOVEMENT_ACC_DURATION_SAFEGUARD_MIN,
                                "highLim":CFG_MOVEMENT_ACC_DURATION_SAFEGUARD_MAX});
        validationRules.append({"name":"motionTime",
                                "required":false,
                                "validationType":"integer|float",
                                "lowLim":CFG_MOTION_TIME_SAFEGUARD_MIN,
                                "highLim":CFG_MOTION_TIME_SAFEGUARD_MAX});
        validationRules.append({"name":"motionVelocity",
                                "required":false,
                                "validationType":"integer|float",
                                "lowLim":CFG_MOTION_VEL_SAFEGUARD_MIN,
                                "highLim":CFG_MOTION_VEL_SAFEGUARD_MAX});
        validationRules.append({"name":"motionDistance",
                                "required":false,
                                "validationType":"integer|float",
                                "fixedValues":[CFG_MOTION_DIST_FIXED_VAL],
                                "lowLim":CFG_MOTION_DIST_SAFEGUARD_MIN,
                                "highLim":CFG_MOTION_DIST_SAFEGUARD_MAX});
        validationRules.append({"name":"motionStopTimeout",
                                "required":false,
                                "validationType":"integer|float",
                                "lowLim":CFG_MOTION_STOP_SAFEGUARD_MIN,
                                "highLim":CFG_MOTION_STOP_SAFEGUARD_MAX});
        rulesCheckRes = _rulesCheck(validationRules, motionMon);
        if (rulesCheckRes != null) return rulesCheckRes;

        // must be movementAccMin <= movementAccMax
        if ("movementAccMin" in motionMon &&
            "movementAccMax" in motionMon) {
            if (motionMon.movementAccMin >
                motionMon.movementAccMax) {
                return "Movement acceleration range limit error";
            }
        }
    }

    if ("geofence" in locTracking) {
        local validationRules = [];
        local geofence = locTracking.geofence;
        // check enable field
        checkEnableRes = _checkEnableField(geofence);
        if (checkEnableRes != null) return checkEnableRes;
        validationRules.append({"name":"lng",
                                "required":false,
                                "validationType":"integer|float",
                                "lowLim":CFG_LONGITUDE_SAFEGUARD_MIN,
                                "highLim":CFG_LONGITUDE_SAFEGUARD_MAX,
                                "dependencies":["lat", "radius"]});
        validationRules.append({"name":"lat",
                                "required":false,
                                "validationType":"integer|float",
                                "lowLim":CFG_LATITUDE_SAFEGUARD_MIN,
                                "highLim":CFG_LATITUDE_SAFEGUARD_MAX,
                                "dependencies":["lng", "radius"]});
        validationRules.append({"name":"radius",
                                "required":false,
                                "validationType":"integer|float",
                                "lowLim":CFG_GEOFENCE_RADIUS_SAFEGUARD_MIN,
                                "highLim":CFG_GEOFENCE_RADIUS_SAFEGUARD_MAX,
                                "dependencies":["lng","lat"]});
        rulesCheckRes = _rulesCheck(validationRules, geofence);
        if (rulesCheckRes != null) return rulesCheckRes;
    }
    if ("repossessionMode" in locTracking) {
        local validationRules = [];
        local repossession = locTracking.repossessionMode;
        // check enable field
        checkEnableRes = _checkEnableField(repossession);
        if (checkEnableRes != null) return checkEnableRes;
        validationRules.append({"name":"after",
                                "required":false,
                                "validationType":"integer",
                                "lowLim": CFG_MIN_TIMESTAMP,
                                "maxLim": CFG_MAX_TIMESTAMP});
        rulesCheckRes = _rulesCheck(validationRules, repossession);
        if (rulesCheckRes != null) return rulesCheckRes;
    }
    if ("bleDevices" in locTracking) {
        local validationRules = [];
        local ble = locTracking.bleDevices;
        // check enable field
        checkEnableRes = _checkEnableField(ble);
        if (checkEnableRes) return checkEnableRes;
        if ("generic" in ble) {
            local bleDevices = ble.generic;
            local validateGenericBLERes = _validateGenericBLE(bleDevices);
            if (validateGenericBLERes != null) return validateGenericBLERes;
        }
        if ("iBeacon" in ble) {
            local iBeacons = ble.iBeacon;
            local validateBeaconRes = _validateBeacon(iBeacons);
            if (validateBeaconRes != null) return validateBeaconRes;
        }
    }
    return null;
}

/**
 * Validation of the SIM update block.
 *
 * @param {table} simUpdate - SIM update configuration table.
 *
 * @return {null | string} null - validation success, otherwise error string.
 */
function _validateSimUpdate(simUpdate) {
    local validationRules = [{
        "name":"duration",
        "required":false,
        "validationType":"integer|float",
        "lowLim":CFG_SIM_UPDATE_DURATION_SAFEGUARD_MIN,
        "highLim":CFG_SIM_UPDATE_DURATION_SAFEGUARD_MAX
    }];

    return _checkEnableField(simUpdate) || _rulesCheck(validationRules, simUpdate);
}

/**
 * Check availability and value type of the "enable" field.
 *
 * @param {table} cfgGroup - Configuration parameters table.
 *
 * @return {null | string} null - validation success, otherwise error string.
 */
function _checkEnableField(cfgGroup) {
    if ("enabled" in cfgGroup) {
        if (typeof(cfgGroup.enabled) != "bool") {
            return "Enable field - type mismatch";
        }
    }
    return null;
}

/**
 * Validation of the generic BLE device configuration.
 *
 * @param {table} bleDevices - Generic BLE device configuration table.
 *
 * @return {null | string} null - validation success, otherwise error string.
 */
function _validateGenericBLE(bleDevices) {
    const BLE_MAC_ADDR = @"(?:\x\x){5}\x\x";
    foreach (bleDeviveMAC, bleDevive  in bleDevices) {
        local regex = regexp(format(@"^%s$", BLE_MAC_ADDR));
        local regexCapture = regex.capture(bleDeviveMAC);
        if (regexCapture == null) {
            return "Generic BLE device MAC address error";
        }
        local rulesCheckRes = _rulesCheck(coordValidationRules, bleDevive);
        if (rulesCheckRes != null) return rulesCheckRes;
    }
    return null;
}

/**
 * Validation of the iBeacon configuration.
 *
 * @param {table} iBeacons - iBeacon configuration table.
 *
 * @return {null | string} null - validation success, otherwise error string.
 */
function _validateBeacon(iBeacons) {
    const IBEACON_UUID = @"(?:\x\x){15}\x\x";
    const IBEACON_MAJOR_MINOR = @"\d{1,5}";
    foreach (iBeaconUUID, iBeacon in iBeacons) {
        local regex = regexp(format(@"^%s$", IBEACON_UUID));
        local regexCapture = regex.capture(iBeaconUUID);
        if (regexCapture == null) {
            return "iBeacon UUID error";
        }
        foreach (majorVal, major in iBeacon) {
            regex = regexp(format(@"^%s$", IBEACON_MAJOR_MINOR));
            regexCapture = regex.capture(majorVal);
            if (regexCapture == null) {
                return "iBeacon \"major\" error";
            }
            // max 2 bytes (65535)
            if (majorVal.tointeger() > CFG_BEACON_MINOR_MAJOR_VAL_MAX) {
                return "iBeacon \"major\" error (more then 65535)";
            }
            foreach (minorVal, minor in major) {
                regexCapture = regex.capture(minorVal);
                if (regexCapture == null) {
                    return "iBeacon \"minor\" error";
                }
                // max 2 bytes (65535)
                if (minorVal.tointeger() > CFG_BEACON_MINOR_MAJOR_VAL_MAX) {
                    return "iBeacon \"minor\" error (more then 65535)";
                }
                local rulesCheckRes = _rulesCheck(coordValidationRules, minor);
                if (rulesCheckRes != null) return rulesCheckRes;
            }
        }
    }
    return null;
}
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


// Configuration API endpoint
const CFG_REST_API_DATA_ENDPOINT = "/cfg";

// Timeout to re-check connection with imp-device, in seconds
const CFG_CHECK_IMP_CONNECT_TIMEOUT = 10;

// Returned HTTP codes
enum CFG_REST_API_HTTP_CODES {
    OK = 200,           // Cfg update is accepted (enqueued)
    INVALID_REQ = 400,  // Incorrect cfg
    UNAUTHORIZED = 401  // No or invalid authentication details are provided
};

// Configuration service class
class CfgService {
    // Messenger instance
    _msngr = null;
    // HTTP Authorization header
    _authHeader = null;
    // Cfg update ("configuration") which waits for successful delivering to the imp-device
    _pendingCfg = null;
    // Cfg update ("configuration") which is being sent to the imp-device,
    // also behaves as "sending in process" flag
    _sendingCfg = null;
    // Timer to re-check connection with imp-device
    _timerSending = null;
    // Cfg reported by imp-device
    _reportedCfg = null;
    // Agent configuration
    _agentCfg = null;

    /**
     * Constructor for Configuration Service Class
     *
     * @param {object} msngr - Messenger instance
     * @param {string} [user] - Username for Basic auth
     * @param {string} [pass] - Password  for Basic auth
     */
    constructor(msngr, user = null, pass = null) {
        _msngr = msngr;
        _msngr.on(APP_RM_MSG_NAME.CFG, _cfgCb.bindenv(this));
        _msngr.onAck(_ackCb.bindenv(this));
        _msngr.onFail(_failCb.bindenv(this));

        try {
            _validateDefaultCfg();
            _loadCfgs();
            _applyAgentCfg(_agentCfg);
        } catch (err) {
            ::error("Initialization failure: " + err, "CfgService");
            return;
        }

        local getRoute = Rocky.on("GET", CFG_REST_API_DATA_ENDPOINT, _getCfgRockyHandler.bindenv(this));
        local patchRoute = Rocky.on("PATCH", CFG_REST_API_DATA_ENDPOINT, _patchCfgRockyHandler.bindenv(this));

        if (user && pass) {
            _authHeader = "Basic " + http.base64encode(user + ":" + pass);

            foreach (route in [getRoute, patchRoute]) {
                route.authorize(_authCb.bindenv(this)).onUnauthorized(_unauthCb.bindenv(this));
            }
        }

        ::info("JSON Cfg Scheme Version: " + CFG_SCHEME_VERSION, "CfgService");
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Authorization callback function.
     *
     * @param context - Rocky.Context object.
     *
     * @return {boolean} - true - authorization success.
     */
    function _authCb(context) {
        return (context.getHeader("Authorization") == _authHeader.tostring());
    }

    /**
     * Unauthorization callback function.
     *
     * @param context - Rocky.Context object
     */
    function _unauthCb(context) {
        context.send(CFG_REST_API_HTTP_CODES.UNAUTHORIZED,
                     { "message": "Unauthorized" });
    }

    /**
     * Handler for configuration received from Imp-Device
     *
     * @param {table} msg - Received message payload.
     * @param customAck - Custom acknowledgment function.
     */
    function _cfgCb(msg, customAck) {
        ::debug("Cfg received from imp-device, msgId = " + msg.id, "CfgService");
        // save it as reported cfg
        _reportedCfg = msg.data;
        _saveCfgs();
    }

    /**
     * HTTP GET request callback function.
     *
     * @param context - Rocky.Context object.
     */
    function _getCfgRockyHandler(context) {
        ::info("GET " + CFG_REST_API_DATA_ENDPOINT + " request from cloud", "CfgService");

        // Table with cfg data to return to the cloud
        local reportToCloud;

        if (_reportedCfg != null) {
            // Cfg data from the imp-device exists. Assumed it contains:
            // {
            //   "description": {
            //     "cfgTimestamp": <number>
            //   },
            //   "configuration": {...}
            // }

            // NOTE: This may be suboptimal. May need to be improved
            // Copy the reported cfg before modification
            reportToCloud = http.jsondecode(http.jsonencode(_reportedCfg));
        } else {
            // No cfg data from the imp-device exists.
            // Add empty "description" fields.
            reportToCloud = { "description": {} };
            ::info("No cfg data from imp-device is available", "CfgService");
        }

        // Add imp-agent part of the data:
        // {
        //   "description": {
        //     "trackerId": <string>,
        //     "cfgSchemeVersion": <string>,
        //     "pendingUpdateId": <string> // if exists
        //   },
        //   "agentConfiguration": {
        //     "debug": {
        //       "logLevel": <string>
        //     }
        //   }
        // }
        reportToCloud.description.trackerId <- imp.configparams.deviceid;
        reportToCloud.description.cfgSchemeVersion <- CFG_SCHEME_VERSION;
        if (_pendingCfg != null) {
            reportToCloud.description.pendingUpdateId <- _pendingCfg.updateId;
        }
        reportToCloud.agentConfiguration <- _agentCfg;

        ::debug("Cfg reported to cloud: " + http.jsonencode(reportToCloud), "CfgService");

        // Return the data to the cloud
        context.send(CFG_REST_API_HTTP_CODES.OK, http.jsonencode(reportToCloud));
    }

    /**
     * HTTP PATCH request callback function.
     *
     * @param context - Rocky.Context object
     */
    function _patchCfgRockyHandler(context) {
        ::info("PATCH " + CFG_REST_API_DATA_ENDPOINT + " request from cloud", "CfgService");

        local newCfg = context.req.body;

        // validate received cfg update
        local validateCfgRes = validateCfg(newCfg);
        if (validateCfgRes != null) {
            ::error(validateCfgRes, "CfgService");
            context.send(CFG_REST_API_HTTP_CODES.INVALID_REQ,
                         validateCfgRes);
            return;
        }
        ::debug("Configuration validated.", "CfgService");

        // apply imp-agent part of cfg if any
        ("agentConfiguration" in newCfg) && _applyAgentCfg(newCfg.agentConfiguration);

        // process imp-device part of cfg, if any
        if ("configuration" in newCfg) {
            // Pending cfg is always overwritten by the new cfg update
            _pendingCfg = newCfg.configuration;
            ::info("Cfg update is pending sending to device, updateId: " +
                   _pendingCfg.updateId, "CfgService");
            if (_sendingCfg == null) {
                // If another sending process is not in progress,
                // then start the sending process
                _sendCfg();
            }
        }

        // Return response to the cloud - cfg update is accepted (enqueued)
        context.send(CFG_REST_API_HTTP_CODES.OK);
    }

    /**
     * Apply imp-agent part of configuration.
     *
     * @param {table} cfg - Agent configuration table.
     */
    function _applyAgentCfg(cfg) {
        if ("debug" in cfg && "logLevel" in cfg.debug) {
            local logLevel = cfg.debug.logLevel.tolower();

            ::info("Imp-agent log level is set to \"" + logLevel + "\"", "CfgService");
            Logger.setLogLevelStr(logLevel);

            _agentCfg.debug.logLevel = cfg.debug.logLevel;
        }

        _saveCfgs();
    }

    function _loadCfgs() {
        local storedData = server.load();

        _agentCfg = "agentCfg" in storedData ? storedData.agentCfg : _defaultAgentCfg();
        _reportedCfg = "reportedCfg" in storedData ? storedData.reportedCfg : null;
    }

    function _saveCfgs() {
        local storedData = server.load();
        storedData.agentCfg <- _agentCfg;
        storedData.reportedCfg <- _reportedCfg;

        try {
            server.save(storedData);
        } catch (err) {
            ::error("Can't save agent cfg in the persistent memory: " + err, "CfgService");
        }
    }

    function _defaultAgentCfg() {
        return http.jsondecode(__VARS.DEFAULT_CFG).agentConfiguration;
    }

    function _validateDefaultCfg() {
        local cfg = null;

        try {
            cfg = http.jsondecode(__VARS.DEFAULT_CFG);
        } catch (err) {
            throw "Can't parse the default configuration: " + err;
        }

        local validateCfgRes = validateCfg(cfg);
        if (validateCfgRes != null) {
            throw "Default configuration validation failure: " + validateCfgRes;
        }
    }

    /**
     * Send configuration to device.
     */
    function _sendCfg() {
        if (_pendingCfg != null) {
            // Sending process is started
            _sendingCfg = _pendingCfg;
            if (device.isconnected()) {
                _msngr.send(APP_RM_MSG_NAME.CFG, _sendingCfg);
            } else {
                // Device is disconnected =>
                // check the connection again after the timeout
                _timerSending && imp.cancelwakeup(_timerSending);
                _timerSending = imp.wakeup(CFG_CHECK_IMP_CONNECT_TIMEOUT,
                                           _sendCfg.bindenv(this));
            }
        }
    }

    /**
     * Callback that is triggered when a message sending fails.
     *
     * @param msg - Messenger.Message object.
     * @param {string} error - A description of the message failure.
     */
    function _failCb(msg, error) {
        local name = msg.payload.name;
        ::debug("Fail, name: " + name + ", error: " + error, "CfgService");
        if (name == APP_RM_MSG_NAME.CFG) {
            // Send/resend the cfg update:
            //   - if there was a new cfg request => send it
            //   - else => resend the failed one
            _sendCfg();
        }
    }

    /**
     * Callback that is triggered when a message is acknowledged.
     *
     * @param msg - Messenger.Message object.
     * @param ackData - Any serializable type -
     *                  The data sent in the acknowledgement, or null if no data was sent
     */
    function _ackCb(msg, ackData) {
        local name = msg.payload.name;
        ::debug("Ack, name: " + name, "CfgService");
        if (name == APP_RM_MSG_NAME.CFG) {
            if (_pendingCfg == _sendingCfg) {
                 // There was no new cfg request during the sending process
                 // => no pending cfg anymore (till the next cfg patch request)
                 _pendingCfg = null;
            }
            // Sending process is completed
            ::info("Cfg update successfully sent to device, updateId: " +
                   _sendingCfg.updateId, "CfgService");
            _sendingCfg = null;
            // Send the next cfg update, if there is any
            _sendCfg();
        }
    }
}

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


// Index page endpoint
const WEBUI_INDEX_PAGE_ENDPOINT = "/";
// Data (latest message from the device, alerts history) API endpoint
const WEBUI_DATA_ENDPOINT = "/web-ui/data";
// Tokens (u-blox, google) setting API endpoint
const WEBUI_TOKENS_ENDPOINT = "/web-ui/tokens";
// Cloud settings (URL, user, pass) API endpoint
const WEBUI_CLOUD_SETTINGS_ENDPOINT = "/web-ui/cloud-settings";

// Maximum alerts to be kept in the history
const WEBUI_ALERTS_HISTORY_LEN = 10;

// Web UI class:
// - Provides HTTP endpoints for Web interface
// - Stores data required for Web interface
class WebUI {
    // Latest data message received from the device
    _latestData = null;
    // Alerts history
    _alertsHistory = null;
    // Tokens setter function
    _tokensSetter = null;
    // Cloud configurator function
    _cloudConfigurator = null;

    /**
     * Constructor for Web UI class
     *
     * @param {function} tokensSetter - Tokens setter function
     * @param {function} cloudConfigurator - Cloud configurator function
     */
    constructor(tokensSetter, cloudConfigurator) {
        _tokensSetter = tokensSetter;
        _cloudConfigurator = cloudConfigurator;

        Rocky.on("GET", WEBUI_INDEX_PAGE_ENDPOINT, _getIndexPageRockyHandler.bindenv(this));
        Rocky.on("GET", WEBUI_DATA_ENDPOINT, _getDataRockyHandler.bindenv(this));
        Rocky.on("PATCH", WEBUI_TOKENS_ENDPOINT, _patchTokensRockyHandler.bindenv(this));
        Rocky.on("PATCH", WEBUI_CLOUD_SETTINGS_ENDPOINT, _patchCloudSettingsRockyHandler.bindenv(this));

        _alertsHistory = [];
    }

    /**
     * Pass new data received from the device
     *
     * @param {table} data - Tokens setter function
     */
    function newData(data) {
        _latestData = data;

        foreach (alert in data.alerts) {
            _alertsHistory.insert(0, {
                "alert": alert,
                "ts": data.timestamp
            });
        }

        if (_alertsHistory.len() > WEBUI_ALERTS_HISTORY_LEN) {
            _alertsHistory.resize(WEBUI_ALERTS_HISTORY_LEN);
        }
    }

    // -------------------- PRIVATE METHODS -------------------- //

    function _getIndexPageRockyHandler(context) {
        ::debug("GET " + WEBUI_INDEX_PAGE_ENDPOINT + " request received", "WebUI");

        // Return the index.html page file
        context.send(200, _indexHtml());
    }

    function _getDataRockyHandler(context) {
        ::debug("GET " + WEBUI_DATA_ENDPOINT + " request received", "WebUI");

        local data = {
            "latestData": _latestData,
            "alertsHistory": _alertsHistory
        };

        // Return the data
        context.send(200, data);
    }

    function _patchTokensRockyHandler(context) {
        ::debug("PATCH " + WEBUI_TOKENS_ENDPOINT + " request received", "WebUI");

        local tokens = context.req.body;
        local ubloxToken = "ublox" in tokens ? tokens.ublox : null;
        local gmapsKey   = "gmaps" in tokens ? tokens.gmaps : null;
        _tokensSetter(ubloxToken, gmapsKey);

        context.send(200);
    }

    function _patchCloudSettingsRockyHandler(context) {
        ::debug("PATCH " + WEBUI_CLOUD_SETTINGS_ENDPOINT + " request received", "WebUI");

        local cloudSettings = context.req.body;
        _cloudConfigurator(cloudSettings.url, cloudSettings.user, cloudSettings.pass);

        context.send(200);
    }

    function _indexHtml() {
        return "<!--\nMIT License\n\nCopyright (C) 2022, Twilio, Inc. <help@twilio.com>\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of\nthis software and associated documentation files (the \"Software\"), to deal in\nthe Software without restriction, including without limitation the rights to\nuse, copy, modify, merge, publish, distribute, sublicense, and/or sell copies\nof the Software, and to permit persons to whom the Software is furnished to do\nso, subject to the following conditions:\n\nThe above copyright notice and this permission notice shall be included in all\ncopies or substantial portions of the Software.\n\nTHE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR\nIMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,\nFITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE\nAUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER\nLIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,\nOUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE\nSOFTWARE.\n-->\n\n<!doctype html>\n<html lang=\"en\">\n<head>\n    <meta charset=\"utf-8\"/>\n    <link rel=\"icon\" href=\"https://progx.s3.amazonaws.com/agent-assets/favicon.ico\"/>\n    <meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"/>\n    <meta name=\"theme-color\" content=\"#000000\"/>\n    <link rel=\"preconnect\" href=\"https://assets.twilio.com\" crossorigin/>\n    <link rel=\"stylesheet\" href=\"https://assets.twilio.com/public_assets/paste-fonts/main-1.2.0/fonts.css\"/>\n    <title>Programmable Asset Tracker</title>\n    <script defer=\"defer\" src=\"https://progx.s3.amazonaws.com/agent-assets/static/js/main.js\"></script>\n    <link href=\"https://progx.s3.amazonaws.com/agent-assets/static/css/main.css\" rel=\"stylesheet\">\n</head>\n<body>\n<noscript>You need to enable JavaScript to run this app.</noscript>\n<div id=\"root\"></div>\n</body>\n</html>";
    }
}


// Main application on Imp-Agent:
// - Forwards Data messages from Imp-Device to Cloud REST API
// - Obtains GNSS Assist data for u-blox from server and returns it to Imp-Device
// - Obtains the location by cell towers and wifi networks info using Google Maps Geolocation API
//   and returns it to Imp-Device
// - Implements REST API for the tracker configuration
//   -- Sends cfg update request to Imp-Device
//   -- Stores actual cfg received from from Imp-Device
class Application {
    // Messenger instance
    _msngr = null;
    // Configuration service instance
    _cfgService = null;
    // Location Assistant instance
    _locAssistant = null;
    // Cloud Client instance
    _cloudClient = null;
    // Web UI instance. If disabled, null
    _webUI = null;

    /**
     * Application Constructor
     */
    constructor() {
        ::info("Application Version: " + APP_VERSION);
        // Initialize library for communication with Imp-Device
        _initMsngr();
        // Initialize Location Assistant
        _initLocAssistant();

        // Initialize configuration service with no authentication
        _initCfgService();
        // Initialize Web UI
        _initWebUI();

        // Always take U-blox Assist Now token from env vars
        _locAssistant.setTokens(__VARS.UBLOX_ASSIST_NOW_TOKEN);
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Create and initialize Messenger instance
     */
    function _initMsngr() {
        _msngr = Messenger();
        _msngr.on(APP_RM_MSG_NAME.DATA, _onData.bindenv(this));
        _msngr.on(APP_RM_MSG_NAME.GNSS_ASSIST, _onGnssAssist.bindenv(this));
        _msngr.on(APP_RM_MSG_NAME.LOCATION_CELL_WIFI, _onLocationCellAndWiFi.bindenv(this));
    }

    /**
     * Create and initialize configuration service instance
     *
     * @param {string} [user] - Username for configuration service authorization
     * @param {string} [pass] - Password for configuration service authorization
     */
    function _initCfgService(user = null, pass = null) {
        Rocky.init();
        _cfgService = CfgService(_msngr, user, pass);
    }

    /**
     * Create and initialize Location Assistant instance
     */
    function _initLocAssistant() {
        _locAssistant = LocationAssistant();
    }

    /**
     * Create and initialize Cloud Client instance
     *
     * @param {string} url - Cloud's URL
     * @param {string} user - Username for Cloud's authorization
     * @param {string} pass - Password for Cloud's authorization
     */
    function _initCloudClient(url, user, pass) {
        _cloudClient = CloudClient(url, user, pass);
    }

    /**
     * Create and initialize Web UI
     */
    function _initWebUI() {
        local tokensSetter = _locAssistant.setTokens.bindenv(_locAssistant);
        local cloudConfigurator = _initCloudClient.bindenv(this);
        _webUI = WebUI(tokensSetter, cloudConfigurator);
    }

    /**
     * Handler for Data received from Imp-Device
     *
     * @param {table} msg - Received message payload.
     * @param {function} customAck - Custom acknowledgment function.
     */
    function _onData(msg, customAck) {
        ::debug("Data received from imp-device, msgId = " + msg.id);
        local data = http.jsonencode(msg.data);

        // If Web UI is enabled, pass there the latest data
        _webUI && _webUI.newData(msg.data);

        if (_cloudClient) {
            _cloudClient.send(data)
            .then(function(_) {
                ::info("Data has been successfully sent to the cloud: " + data);
            }.bindenv(this), function(err) {
                ::error("Cloud reported an error while receiving data: " + err);
                ::error("The data caused this error: " + data);
            }.bindenv(this));
        } else {
            ::info("No cloud configured. Data received but not sent further: " + data);
        }
    }

    /**
     * Handler for GNSS Assist request received from Imp-Device
     *
     * @param {table} msg - Received message payload.
     * @param {function} customAck - Custom acknowledgment function.
     */
    function _onGnssAssist(msg, customAck) {
        local ack = customAck();

        _locAssistant.getGnssAssistData()
        .then(function(data) {
            ::info("Assist data downloaded");
            ack(data);
        }.bindenv(this), function(err) {
            ::error("Error during downloading assist data: " + err);
            // Send `null` in reply to the request
            ack(null);
        }.bindenv(this));
    }

    /**
     * Handler for Location By Cell Info and WiFi request received from Imp-Device
     *
     * @param {table} msg - Received message payload.
     * @param {function} customAck - Custom acknowledgment function.
     */
    function _onLocationCellAndWiFi(msg, customAck) {
        local ack = customAck();

        _locAssistant.getLocationByCellInfoAndWiFi(msg.data)
        .then(function(location) {
            ::info("Location obtained using Google Geolocation API");
            ack(location);
        }.bindenv(this), function(err) {
            ::error("Error during location obtaining using Google Geolocation API: " + err);
            ack(null);
        }.bindenv(this));
    }
}

// ---------------------------- THE MAIN CODE ---------------------------- //

// Run the application
app <- Application();
