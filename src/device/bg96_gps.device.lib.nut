/*
 * BG96_GPS library
 * Copyright 2020 Twilio
 *
 * MIT License
 * SPDX-License-Identifier: MIT
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:

 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.

 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
 * EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
 * OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */


/*
 * Enums
 */
enum BG96_ERROR_CODE {
    IMPOS_TIMEOUT                   = "-1",
    IMPOS_MODEM_NOT_READY           = "-2",
    IMPOS_MODEM_IS_BUSY             = "-3",
    IMPOS_INVALID_PARAM             = "-4",
    IMPOS_TRANSMISSION_FAIL         = "-5",
    FILE_INVALID_INPUT              = "400",
    FILE_SIZE_MISMATCH              = "401",
    FILE_READ_ZERO_BYTE             = "402",
    FILE_DRIVE_FULL                 = "403",
    FILE_NOT_FOUND                  = "405",
    FILE_INVALID_NAME               = "406",
    FILE_ALREADY_EXISTS             = "407",
    FILE_WRITE_FAIL                 = "409",
    FILE_OPEN_FAIL                  = "410",
    FILE_READ_FAIL                  = "411",
    FILE_MAX_OPEN_FILES             = "413",
    FILE_READ_ONLY                  = "414",
    FILE_INVALID_DESCRIPTOR         = "416",
    FILE_LIST_FAIL                  = "417",
    FILE_DELETE_FAIL                = "418",
    FILE_GET_DISK_INFO_FAIL         = "419",
    FILE_NO_SPACE                   = "420",
    FILE_TIMEOUT                    = "421",
    FILE_TOO_LARGE                  = "423",
    FILE_INVALID_PARAM              = "425",
    FILE_ALREADY_OPEN               = "426",
    GPS_INVALID_PARAM               = "501",
    GPS_OPERATION_NOT_SUPPORTED     = "502",
    GPS_GNSS_SUBSYSTEM_BUSY         = "503",
    GPS_SESSION_IS_ONGOING          = "504",
    GPS_SESSION_NOT_ACTIVE          = "505",
    GPS_OPERATION_TIMEOUT           = "506",
    GPS_FUNCTION_NOT_ENABLED        = "507",
    GPS_TIME_INFO_ERROR             = "508",
    GPS_XTRA_NOT_ENABLED            = "509",
    GPS_VALIDITY_TIME_OUT_OF_RANGE  = "512",
    GPS_INTERNAL_RESOURCE_ERROR     = "513",
    GPS_GNSS_LOCKED                 = "514",
    GPS_END_BY_E911                 = "515",
    GPS_NO_FIX_NOW                  = "516",
    GPS_GEO_FENCE_ID_DOES_NOT_EXIST = "517",
    GPS_UNKNOWN_ERROR               = "549"
}

enum BG96_GNSS_ON_DEFAULT {
    MODE                = 1,    // Stand Alone is the only mode supported (1)
    MAX_POS_TIME_SEC    = 30,   // Sec max pos time (30)
    FIX_ACCURACY_METERS = 50,   // Fix accuracy in meters (50)
    NUM_FIX_CHECKS      = 0,    // Num of checks after fix before powering down GPS (0 - continuous)
    GET_LOC_FREQ_SEC    = 1,    // Check every x sec (1)
    RETRY_TIME_SEC      = 1,    // Time to wait for modem to power up
}

enum BG96_GNSS_LOCATION_MODE {
    ZERO,   // <latitude>,<longitude> format: ddmm.mmmm N/S,dddmm.mmmm E/W
    ONE,    // <latitude>,<longitude> format: ddmm.mmmmmm,N/S,dddmm.mmmmmm,E/W
    TWO     // <latitude>,<longitude> format: (-)dd.ddddd,(-)ddd.ddddd
}

// Stale location data is often returned immediately after power up
const BG96_GPS_EN_POLLING_TIMEOUT = 3;
// Duration (sec) of enabling the assist function of BG96
const BG96_ASSIST_ENABLE_DURATION = 0.5;
// Duration (sec) of loading fresh assist data into BG96
const BG96_ASSIST_LOAD_DURATION = 2.0;

/*
 * Library
 */
BG96_GPS <- {

    VERSION   = "0.1.5_alert_custom_0.1.1",

    /*
     * PRIVATE PROPERTIES
     */
     _locTimer = null,
    _session   = null,
    _minSuppportedImpOS = 43.0,
    _impOSVersion = null,
    _pollTimer = null,

    /*
     * PUBLIC FUNCTIONS
     */
    isGNSSEnabled = function() {
        _checkOS();

        if (_session == null) return false;

        try {
            local resp = _session.getstate();
            return (resp.state == 1);
        } catch(e) {
            _log(e);
        }
    },

    enableGNSS = function(opts = {}) {
        _checkOS();
        local gnssMode   = ("gnssMode" in opts)   ? opts.gnssMode   : BG96_GNSS_ON_DEFAULT.MODE;
        local posTime    = ("maxPosTime" in opts) ? opts.maxPosTime : BG96_GNSS_ON_DEFAULT.MAX_POS_TIME_SEC;
        local accuracy   = ("accuracy" in opts)   ? opts.accuracy   : BG96_GNSS_ON_DEFAULT.FIX_ACCURACY_METERS;
        local numFixes   = ("numFixes" in opts)   ? opts.numFixes   : BG96_GNSS_ON_DEFAULT.NUM_FIX_CHECKS;
        local checkFreq  = ("checkFreq" in opts)  ? opts.checkFreq  : BG96_GNSS_ON_DEFAULT.GET_LOC_FREQ_SEC;
        local retryTime  = ("retryTime" in opts)  ? opts.retryTime  : BG96_GNSS_ON_DEFAULT.RETRY_TIME_SEC;
        local locMode    = ("locMode" in opts)    ? opts.locMode    : BG96_GNSS_LOCATION_MODE.TWO;
        local onEnabled  = ("onEnabled" in opts && typeof opts.onEnabled == "function")   ? opts.onEnabled  : null;
        local onLocation = ("onLocation" in opts && typeof opts.onLocation == "function") ? opts.onLocation : null;
        local assistData = ("assistData" in opts) ? opts.assistData : null;
        local useAssist  = ("useAssist" in opts) ? opts.useAssist : false;

        if (!isGNSSEnabled()) {
            if (_session == null) {
                try {
                    local wasReady = false;

                    _session = hardware.gnss.open(function(t) {
                        _log("Session is " + (t.ready == 0 ? "not ready" : "ready"));
                        if (!wasReady && t.ready == 1) {
                            wasReady = true;
                            enableGNSS(opts);
                        }
                    }.bindenv(this));
                } catch (err) {
                    _log("Exception was thrown by hardware.gnss.open(): " + err, true);
                    onEnabled && onEnabled(err);
                }

                return;
            }

            if (assistData) {
                try {
                    _session.assist.load(function(t) {
                        _log("Assist data " + (t.status == 0 ? "loaded" : "not loaded"));
                        if (t.status != 0 && "message" in t) _log("Error: " + t.message, true);
                        if ("restart" in t) _log("Modem restarted? " + (t.restart == 0 ? "No" : "Yes"));

                        // To let the new assist data be applied, we immediately enable the assist function
                        try {
                            _session.assist.enable();
                        } catch (err) {
                            // If there is an exception, we just disable assist to not run into an infinite loop
                            opts.useAssist <- false;
                            opts.assistData = null;
                            _log("Exception was thrown by session.assist.enable(): " + err, true);
                            enableGNSS(opts);
                            return;
                        }
                        // Sleep to let the opration be finished
                        imp.sleep(BG96_ASSIST_LOAD_DURATION);

                        opts.assistData = null;
                        if (!("useAssist" in opts)) opts.useAssist <- true;
                        enableGNSS(opts);
                    }.bindenv(this), assistData);
                } catch (err) {
                    _log("Exception was thrown by session.assist.load(): " + err, true);
                }

                return;
            }

            if (useAssist) {
                // FROM 0.1.5 -- check we have assist data before proceeding
                // This will be the case if 'enableGNSS()' called with 'useAssist' set true,
                // but 'assistData' is null or passed bad data
                if (isAssistDataValid().valid) {
                    // There is assist data present, so proceed to enable
                    local res = null;
                    try {
                        res = _session.assist.enable();
                    } catch (err) {
                        _log("Exception was thrown by session.assist.enable(): " + err, true);
                    }

                    if (res != null) {
                        // Sleep to let the opration be finished. Otherwise, session.assist.read() will return zero/empty data
                        // TODO: Not sure if this is enough to get valid info..
                        imp.sleep(BG96_ASSIST_ENABLE_DURATION);
                        _log("Assist " + (res.status == 0 ? "enabled" : "not enabled"));
                    }
                } else {
                    _log("Assist data not present or overdue -- cannot enable Assist", true);
                }
            }

            local resp = null;
            try {
                resp = _session.enable(gnssMode, posTime, accuracy, numFixes, checkFreq);
            } catch (err) {
                _log("Exception was thrown by session.enable(): " + err, true);
                onEnabled && onEnabled(err);
                return;
            }

            if (resp.status != 0) {
                local status = resp.status.tostring();
                if (status != BG96_ERROR_CODE.GPS_SESSION_IS_ONGOING) {
                    _log("Error enabling GNSS: " + resp.status, true);
                    onEnabled && onEnabled("Error enabling GNSS: " + resp.status);
                    return;
                }
                imp.wakeup(retryTime, function() {
                    enableGNSS(opts);
                }.bindenv(this))
            } else {
                onEnabled && onEnabled(null);
                if (onLocation != null) {
                    // If there is no delay returns stale loc on first 2 (1sec) requests
                    if (_pollTimer != null) imp.cancelwakeup(_pollTimer);
                    _pollTimer = imp.wakeup(BG96_GPS_EN_POLLING_TIMEOUT, function() {
                        _pollLoc(locMode, checkFreq, onLocation, posTime - BG96_GPS_EN_POLLING_TIMEOUT);
                    }.bindenv(this));
                }
            }
        } else {
            // TODO: Assist data is not loaded if already enabled
            _log("Already enabled");
            onEnabled && onEnabled(null);
            if (onLocation != null) {
                if (_pollTimer != null) imp.cancelwakeup(_pollTimer);
                _pollTimer = imp.wakeup(BG96_GPS_EN_POLLING_TIMEOUT, function() {
                    _pollLoc(locMode, checkFreq, onLocation, posTime - BG96_GPS_EN_POLLING_TIMEOUT);
                }.bindenv(this));
            }
        }
    },

    // NOTE Cancels _poll location timer if running
    disableGNSS = function() {
        _checkOS();

        // Always cancel location timer
        _cancelLocTimer();
        if (_pollTimer != null) imp.cancelwakeup(_pollTimer);

        if (isGNSSEnabled()) {
            local resp = null;
            try {
                resp = _session.disable();
            } catch (err) {
                _log("Exception was thrown by session.disable(): " + err, true);
                return false;
            }

            if (resp.status != 0) {
                _log("Error disabling GNSS: " + resp.error);
                return false;
            } else {
                _log("Disabled");
            }
        }

        _session = null;
        return true;
    },

    getLocation = function(opts = {}) {
        _checkOS();

        local poll       = ("poll" in opts) ? opts.poll : false;
        local mode       = ("mode" in opts) ? opts.mode : BG96_GNSS_LOCATION_MODE.ZERO;
        local checkFreq  = ("checkFreq" in opts) ? opts.checkFreq : BG96_GNSS_ON_DEFAULT.GET_LOC_FREQ_SEC;
        local onLocation = ("onLocation" in opts && typeof opts.onLocation == "function") ? opts.onLocation : null;

        // If we have no callback just return an error
        if (onLocation == null) {
            return { "error" : "onLocation callback required" };
        }

        if (poll) {
            _pollLoc(mode, checkFreq, onLocation);
        } else {
            _getLoc(mode, function(loc) {
                if (loc == null) loc = { "error" : "GPS fix not available" };
                onLocation(loc);
            });
        }
    },

    // Is the assist data good?
    isAssistDataValid = function() {
        _checkOS();

        local t = null;
        try {
            t = _session.assist.read();
        } catch (err) {
            _log("Exception was thrown by session.assist.read(): " + err, true);
            return {"valid": false};
        }

        if (t.status == 0) {
            local validTime = _getValidTime(t.injecteddatatime, t.xtradatadurtime);
            _log("Assist data is valid for " + validTime + " minutes");
            _log("Assist data became valid on " + t.injecteddatatime);

            return {
                "valid": validTime > 0,
                "time": validTime
            }
        }

        return {"valid": false};
    },

    // Delete any existing assist data
    // ***** UNTESTED *****
    deleteAssistData = function(mode = 3) {
        _checkOS();

        if (isGNSSEnabled()) {
            // GNSS enabled, so disable before deleting
            local resp = null;
            try {
                resp = _session.disable();
            } catch (err) {
                _log("Exception was thrown by session.disable(): " + err, true);
                return;
            }

            if (resp.status != 0) {
                _log(format("Error disabling GNSS: %i -- could not delete assist data" resp.error), true);
            } else {
                // GNSS now disabled, so we can proceed with deletion
                _deleteAssist(mode);
            }
        } else {
            if (_session == null) {
                // We have to make a session in order to delete the assist data
                try {
                    _session = hardware.gnss.open(function(t) {
                        if (t.ready == 1) _deleteAssist(mode);
                    }.bindenv(this));
                } catch (err) {
                    _log("Exception was thrown by hardware.gnss.open(): " + err, true);
                }
            } else {
                _deleteAssist(mode);
            }
        }
    },

    /*
     * PRIVATE FUNCTIONS -- DO NOT CALL DIRECTLY
     */

    // Loop that polls for location, if location data or error (excluding no fix available) is received it is
    // passed to the onLoc callback
    _pollLoc = function(mode, checkFreq, onLoc, timeout = null) {
        // Only allow one schedule timer at a time
        _cancelLocTimer();

        if (timeout != null) {
            if (timeout <= 0) {
                imp.wakeup(0, function() { onLoc({"error": "Positioning timeout"}); }.bindenv(this));
                return;
            }

            timeout -= checkFreq;
        }

        // Schedule next location check
        _locTimer = imp.wakeup(checkFreq, function() {
            _pollLoc(mode, checkFreq, onLoc, timeout);
        }.bindenv(this));

        // Fetch and process location
        // Returns `null` if GPS error is no fix now, otherwise returns table with keys fix or error
        _getLoc(mode, function(loc) {
            if (loc != null) {
                // Pass error or location fix to main application
                imp.wakeup(0, function() { onLoc(loc); }.bindenv(this));
            }
        });
    },

    // Sends AT command to get location, mode parameter sets the data lat/lng data format
    // Calls back with null if no fix is available or the response as a table that may contain slots:
        // error (string): The error encountered
        // fix (table/string): response data string if location parsing failed otherwise a table with
        // slots: cog, alt, fixType, time, numSats, lat, lon, spkm, spkn, utc, data, hdop
    _getLoc = function(mode, cb) {
        try {
            _session.readposition(function(resp) {
                local data = {};
                if (resp.status != 0) {
                    // Look for expected errors
                    local errorCode = resp.status.tostring();
                    switch (errorCode) {
                        case BG96_ERROR_CODE.GPS_NO_FIX_NOW:
                            _log("GPS fix not available");
                            return cb(null);
                        case BG96_ERROR_CODE.GPS_SESSION_NOT_ACTIVE:
                            _log("GPS not enabled.");
                            data.error <- "GPS not enabled";
                            return cb(data);
                        case BG96_ERROR_CODE.IMPOS_TIMEOUT:
                        case BG96_ERROR_CODE.IMPOS_MODEM_NOT_READY:
                        case BG96_ERROR_CODE.IMPOS_MODEM_IS_BUSY:
                            _log("Trying getting location again...");
                            return cb(null);
                        default:
                            _log("GPS location request failed with error: " + errorCode);
                            data.error <- "Error code: " + errorCode;
                            return cb(data);
                    }
                }

                if (resp.status == 0 && "quectel" in resp) {
                    data.fix <- _parseLocData(resp.quectel, mode);
                }

                cb(data);
            }.bindenv(this), mode);
        } catch (err) {
            _log("Exception was thrown by session.readposition(): " + err, true);
            cb(null);
        }
    },

    // Cancels location polling timer
    _cancelLocTimer = function() {
        if (_locTimer != null) {
            imp.cancelwakeup(_locTimer);
            _locTimer = null;
        }
    },

    // Format GPS timestamp
    _formatTimeStamp = function(d, utc) {
        // Input d: DDMMYY, utc HHMMSS.S
        // Formatted result: YYYY/MM/DD,hh:mm:ss
        return format("20%s/%s/%s,%s:%s:%s", d.slice(4),
                                             d.slice(2, 4),
                                             d.slice(0, 2),
                                             utc.slice(0, 2),
                                             utc.slice(2, 4),
                                             utc.slice(4));
    },

    // Parses location data into table based on mode
    _parseLocData = function(parsed, mode) {
        _log("Parsing location data");
        try {
            switch(mode) {
                case BG96_GNSS_LOCATION_MODE.ZERO:
                    // 190629.0,3723.7238N,12206.1395W,1.0,16.0,2,188.18,0.0,0.0,031219,09
                case BG96_GNSS_LOCATION_MODE.TWO:
                    // 190629.0,37.39540,-122.10232,1.0,16.0,2,188.18,0.0,0.0,031219,09
                case BG96_GNSS_LOCATION_MODE.ONE:
                    // 190629.0,3723.723831,N,12206.139526,W,1.0,16.0,2,188.18,0.0,0.0,031219,09
                     return {
                        "utc"     : parsed.utc,
                        "lat"     : parsed.latitude,
                        "lon"     : parsed.longitude,
                        "hdop"    : parsed.hdop,
                        "alt"     : parsed.altitude,
                        "fixType" : parsed.fix,
                        "cog"     : parsed.cog,
                        "spkm"    : parsed.spkm,
                        "spkn"    : parsed.spkn,
                        "date"    : parsed.date,
                        "numSats" : parsed.nsat,
                        "time"    : _dateToTimestamp(_formatTimeStamp(parsed.date, parsed.utc))
                    };
                default:
                    throw "Unknown mode";
            }
        } catch(ex) {
            _log("Error parsing GPS data " + ex);
            return parsed;
        }
    },

    _log = function(msg, isError = false) {
        if (isError) {
            ::error(msg, "BG96_GPS");
        } else {
            ::debug(msg, "BG96_GPS");
        }
    },

    // Check we're running on a correct system
    _checkOS = function() {
        if (_impOSVersion == null) {
            local n = split(imp.getsoftwareversion(), "-");
            _impOSVersion = n[2].tofloat();
        }

        try {
            assert(_impOSVersion >= _minSuppportedImpOS);
        } catch (exp) {
            throw "BG96_GPS 0.1.0 requires impOS 43 or above";
        }
    },

    // FROM 0.1.5
    // Get assist data remaining validity period in mins
    // 'uploadDate' is a string of format: YYYY/MM/DD,hh:mm:ss
    _getValidTime = function(uploadDate, duration) {
        local uploadTs = _dateToTimestamp(uploadDate);
        local timeRemaining = duration - (time() - uploadTs) / 60;
        return timeRemaining > 0 ? timeRemaining : 0;
    },

    // date is a string of format: YYYY/MM/DD,hh:mm:ss
    _dateToTimestamp = function(date) {
        try {
            date = split(date, ",");
            date[0] = split(date[0], "/");
            date[1] = split(date[1], ":");

            local y = date[0][0].tointeger();
            local m = date[0][1].tointeger();
            local d = date[0][2].tointeger();
            local hrs = date[1][0].tointeger();
            local min = date[1][1].tointeger();
            local sec = date[1][2].tointeger();
            local ts;

            // January and February are counted as months 13 and 14 of the previous year
            if (m <= 2) {
                m += 12;
                y -= 1;
            }

            // Convert years to days
            ts = (365 * y) + (y / 4) - (y / 100) + (y / 400);
            // Convert months to days
            ts += (30 * m) + (3 * (m + 1) / 5) + d;
            // Unix time starts on January 1st, 1970
            ts -= 719561;
            // Convert days to seconds
            ts *= 86400;
            // Add hours, minutes and seconds
            ts += (3600 * hrs) + (60 * min) + sec;

            return ts;
        } catch (err) {
            _log("Couldn't parse the date: " + err, true);
            return 0;
        }
    },

    // FROM 0.1.5
    _deleteAssist = function(mode) {
        local res = null;
        try {
            res = _session.assist.reset(mode);
        } catch (err) {
            _log("Exception was thrown by session.assist.reset(): " + err, true);
            return;
        }

        if (res.status == 0) {
            _log("Assist data deleted");
        } else {
            local err = format("[BG96_GPS] Could not delete assist data (status %i)", res.status);
            _log(err, true);
        }
    }
}
