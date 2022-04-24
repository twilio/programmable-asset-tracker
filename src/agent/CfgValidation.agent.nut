
// Supported configuration JSON format/scheme version
const CFG_SCHEME_VERSION = "1.0";

// Configuration safeguard/validation constants:

// "connectingPeriod"
// How often the tracker connects to network (minimal value), in seconds.
// TODO: adjust
const CFG_CONNECTING_SAFEGUARD_MIN = 10.0;
// How often the tracker connects to network (maximal value), in seconds.
// TODO: adjust
const CFG_CONNECTING_SAFEGUARD_MAX = 360000.0;

// "readingPeriod"
// How often the tracker polls various data (minimal value), in seconds.
// TODO: adjust
const CFG_READING_SAFEGUARD_MIN = 10.0;
// How often the tracker polls various data (maximal value), in seconds.
// TODO: adjust
const CFG_READING_SAFEGUARD_MAX = 360000.0;

// "locReadingPeriod"
// How often the tracker obtains a location (minimal value), in seconds.
// TODO: adjust
const CFG_LOC_READING_SAFEGUARD_MIN = 10.0;
// How often the tracker obtains a location (maximal value), in seconds.
// TODO: adjust
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
// 31.03.2020 12:53:04 - TODO: adjust
const CFG_MIN_TIMESTAMP = "1585666384";
// Maximal start time of repossesion, Unix timestamp
// 17.04.2035 18:48:49 - TODO: adjust
const CFG_MAX_TIMESTAMP = "2060448529";

// Maximal value of iBeacon minor, major
const CFG_BEACON_MINOR_MAJOR_VAL_MAX = 65535;

// Minimal length of a string.
const CFG_STRING_LENGTH_MIN = 1;
// Maximal length of a string.
const CFG_STRING_LENGTH_MAX = 50;

// validation rules for coordinates
coordValidationRules <- [{"name":"lng",
                          "required":false,
                          "validationType":"float", 
                          "lowLim":CFG_LONGITUDE_SAFEGUARD_MIN, 
                          "highLim":CFG_LONGITUDE_SAFEGUARD_MAX,
                          "dependencies":["lat"]},
                         {"name":"lat",
                          "required":false,
                          "validationType":"float", 
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
 *          "validationType": {string} - Parameter type ("float", "string", "integer").
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
                if (typeof(field) != rule.validationType) {
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
            return ("Field: "  + fieldName + " - not exist");
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
        return ("Unknown log level type");
    }

    switch (logLevels.logLevel) {
        case "DEBUG":
        case "INFO":
        case "ERROR":
            break;
        default:
            return ("Unknown log level");
    }
    return null;
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
                            "validationType":"float", 
                            "lowLim":CFG_CONNECTING_SAFEGUARD_MIN, 
                            "highLim":CFG_CONNECTING_SAFEGUARD_MAX});
    validationRules.append({"name":"readingPeriod",
                            "required":false,
                            "validationType":"float", 
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
                                        "validationType":"float", 
                                        "lowLim":CFG_CHARGE_LEVEL_THR_SAFEGUARD_MIN, 
                                        "highLim":CFG_CHARGE_LEVEL_THR_SAFEGUARD_MAX});
                break;
            case "temperatureLow":
            case "temperatureHigh":
                // industrial temperature range
                validationRules.append({"name":"threshold",
                                        "required":false,
                                        "validationType":"float", 
                                        "lowLim":CFG_TEMPERATURE_THR_SAFEGUARD_MIN, 
                                        "highLim":CFG_TEMPERATURE_THR_SAFEGUARD_MAX});
                validationRules.append({"name":"hysteresis",
                                        "required":false,
                                        "validationType":"float", 
                                        "lowLim":CFG_TEMPERATURE_HYST_SAFEGUARD_MIN,
                                        "highLim":CFG_TEMPERATURE_HYST_SAFEGUARD_MAX});
                break;
            case "shockDetected":
                // LIS2DH12 maximum shock threshold - 16 g
                validationRules.append({"name":"threshold",
                                        "required":false,
                                        "validationType":"float", 
                                        "lowLim":CFG_SHOCK_ACC_SAFEGUARD_MIN, 
                                        "highLim":CFG_SHOCK_ACC_SAFEGUARD_MAX});
                break;
            case "tamperingDetected":
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
                                "validationType":"float", 
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
                                "validationType":"float", 
                                "lowLim":CFG_MOVEMENT_ACC_SAFEGUARD_MIN, 
                                "highLim":CFG_MOVEMENT_ACC_SAFEGUARD_MAX,
                                "dependencies":["movementAccMax"]});
        validationRules.append({"name":"movementAccMax",
                                "required":false,
                                "validationType":"float", 
                                "lowLim":CFG_MOVEMENT_ACC_SAFEGUARD_MIN, 
                                "highLim":CFG_MOVEMENT_ACC_SAFEGUARD_MAX,
                                "dependencies":["movementAccMin"]});
        // min 1/ODR (current 100 Hz), max INT1_DURATION - 127/ODR
        validationRules.append({"name":"movementAccDur",
                                "required":false,
                                "validationType":"float", 
                                "lowLim":CFG_MOVEMENT_ACC_DURATION_SAFEGUARD_MIN, 
                                "highLim":CFG_MOVEMENT_ACC_DURATION_SAFEGUARD_MAX});
        validationRules.append({"name":"motionTime",
                                "required":false,
                                "validationType":"float", 
                                "lowLim":CFG_MOTION_TIME_SAFEGUARD_MIN, 
                                "highLim":CFG_MOTION_TIME_SAFEGUARD_MAX});
        validationRules.append({"name":"motionVelocity",
                                "required":false,
                                "validationType":"float", 
                                "lowLim":CFG_MOTION_VEL_SAFEGUARD_MIN, 
                                "highLim":CFG_MOTION_VEL_SAFEGUARD_MAX});
        validationRules.append({"name":"motionDistance",
                                "required":false,
                                "validationType":"float", 
                                "fixedValues":[CFG_MOTION_DIST_FIXED_VAL],
                                "lowLim":CFG_MOTION_DIST_SAFEGUARD_MIN, 
                                "highLim":CFG_MOTION_DIST_SAFEGUARD_MAX});
        rulesCheckRes = _rulesCheck(validationRules, motionMon);
        if (rulesCheckRes != null) return rulesCheckRes;

        // must be movementAccMin < movementAccMax
        if ("movementAccMin" in motionMon && 
            "movementAccMax" in motionMon) {
            if (motionMon.movementAccMin >= 
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
                                "validationType":"float", 
                                "lowLim":CFG_LONGITUDE_SAFEGUARD_MIN, 
                                "highLim":CFG_LONGITUDE_SAFEGUARD_MAX,
                                "dependencies":["lat", "radius"]});
        validationRules.append({"name":"lat",
                                "required":false,
                                "validationType":"float", 
                                "lowLim":CFG_LATITUDE_SAFEGUARD_MIN, 
                                "highLim":CFG_LATITUDE_SAFEGUARD_MAX,
                                "dependencies":["lng", "radius"]});
        validationRules.append({"name":"radius",
                                "required":false,
                                "validationType":"float", 
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
                                "validationType":"string", 
                                "minLen":CFG_STRING_LENGTH_MIN,
                                "maxLen":CFG_STRING_LENGTH_MAX,
                                "minTimeStamp": CFG_MIN_TIMESTAMP,
                                "maxTimeStamp": CFG_MAX_TIMESTAMP});
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
