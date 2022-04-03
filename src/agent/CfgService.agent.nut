@set CLASS_NAME = "CfgService" // Class name for logging

// Username to access the REST API
const CFG_SERVICE_REST_API_USERNAME = "test";
// Password to access the REST API
const CFG_SERVICE_REST_API_PASSWORD = "test";
// API endpoints:
const CFG_SERVICE_REST_API_DATA_ENDPOINT = "/cfg";
// Timeout to re-check connection with imp-device, in seconds
const CFG_SERVICE_CHECK_IMP_CONNECT_TIMEOUT = 10;

// Minimal shock acceleration alert threshold, in g.
const CFG_SERVICE_SHOCK_ACC_SAFEGUARD_MIN = 0.125;
// Maximal shock acceleration alert threshold, in g.
const CFG_SERVICE_SHOCK_ACC_SAFEGUARD_MAX = 16.0;
// How often the tracker connects to network (minimal value), in seconds.
const CFG_SERVICE_CONNECTING_SAFEGUARD_MIN = 10.0;
// How often the tracker connects to network (maximal value), in seconds.
const CFG_SERVICE_CONNECTING_SAFEGUARD_MAX = 360000.0;
// How often the tracker polls various data (minimal value), in seconds.
const CFG_SERVICE_READING_SAFEGUARD_MIN = 10.0;
// How often the tracker polls various data (maximal value), in seconds.
const CFG_SERVICE_READING_SAFEGUARD_MAX = 360000.0;
// Minimal distance to determine motion detection condition, in meters.
const CFG_SERVICE_MOTION_DIST_SAFEGUARD_MIN = 1.0;
// Minimal distance to determine motion detection condition, in meters.
const CFG_SERVICE_MOTION_DIST_SAFEGUARD_MAX = 1000.0;
// Mean Earth radius, in meters.
const CFG_SERVICE_EARTH_RADIUS = 6371009.0;
// Unix timestamp 31.03.2020 18:53:04 (example)
const CFG_SERVICE_MIN_TIMESTAMP = "1585666384";
// Minimal location reading period, in seconds.
const CFG_SERVICE_LOC_READING_SAFEGUARD_MIN = 0.1;
// Maximal location reading period, in seconds.
const CFG_SERVICE_LOC_READING_SAFEGUARD_MAX = 360000.0;
// Maximal count of sending configuration in queue
const CFG_SERVICE_MAX_COUNT_SENDING_CFG = 5;

// Enum for HTTP codes 
enum CFG_SERVICE_HTTP_CODES {
    OK = 200,
    INVALID_REQ = 400,
    UNAUTHORIZED = 401,
    TOO_MANY_REQ = 429
};

// Configuration service class
class CfgService {
    // Messenger instance
    _msngr = null;
    // Rocky instance
    _rocky = null;
    // HTTP Authorization 
    _authHeader = null;
    // Reported configuration
    _reportedCfg = null;
    // Latest configuration applied time
    _lastCfgUpdAplTime = null;
    // Pending configuration Id
    _pendingUpdateId = null;
    // Pending configuration flag
    _isPendingCfg = null;
    // Current sending configuration
    _currentSendingCfg = null;
    // Queue sheduler timer
    _timerQueue = null;
    // Sending configuration
    _sendingCfgs = null;
    // Coordinates validation rules
    _coordValidationRules = null;

    /**
     * Constructor for Configuration Service Class
     *
     * @param {object} msngr - Messenger instance
     * @param {object} rocky - Rocky instance
     */
    constructor(msngr, rocky) {
        _msngr = msngr;
        _rocky = rocky;
        _msngr.on(APP_RM_MSG_NAME.CFG, _cfgCb.bindenv(this));
        _msngr.onAck(_ackCb.bindenv(this));
        _msngr.onFail(_failCb.bindenv(this));

        _sendingCfgs = [];
        _isPendingCfg = false;
        _authHeader = "Basic " + 
                      http.base64encode(CFG_SERVICE_REST_API_USERNAME + 
                      ":" + 
                      CFG_SERVICE_REST_API_PASSWORD);
        // coordinates validation rules
        _coordValidationRules = [{"name":"lng",
                                  "required":true,
                                  "validationType":"float", 
                                  "lowLim":-180.0, 
                                  "highLim":180.0},
                                 {"name":"lat",
                                  "required":true,
                                  "validationType":"float", 
                                  "lowLim":-90.0, 
                                  "highLim":90.0}];
    }

    /**
     * Set Rocky callback functions.
     */
    function init() {
        _rocky.authorize(_authCb.bindenv(this));
        _rocky.onUnauthorized(_unauthCb.bindenv(this));
        _rocky.on("GET", 
                  CFG_SERVICE_REST_API_DATA_ENDPOINT, 
                  _getCfgRockyHandler.bindenv(this), 
                  null);
        _rocky.on("PATCH", 
                  CFG_SERVICE_REST_API_DATA_ENDPOINT, 
                  _patchCfgRockyHandler.bindenv(this), 
                  null);
    }

    // -------------------- PRIVATE METHODS -------------------- //

   /**
     * HTTP GET request callback function.
     *
     * @param context - Rocky.Context object.
     */
    function _getCfgRockyHandler(context) {
        local descr = {
                          "trackerId": imp.configparams.deviceid,
                          "cfgSchemeVersion": "1.1"
                      };
        if (_isPendingCfg) {
            descr["pendingUpdateId"] <- _pendingUpdateId;
        }
        if (_reportedCfg == null) {
            // only description is returned
            ::debug("Only description is returned", "@{CLASS_NAME}");
            context.send(CFG_SERVICE_HTTP_CODES.OK, http.jsonencode(descr));
        } else {
            if (_lastCfgUpdAplTime != null) {
                descr["cfgTimestamp"] <- _lastCfgUpdAplTime;
            }
            if ("description" in _reportedCfg) {
                ::debug("Description exist in reported cfg", "@{CLASS_NAME}");
            } else {
                _reportedCfg["description"] <- descr;
            }
            // Returns reported configuration
            ::debug("Returns reported configuration", "@{CLASS_NAME}");
            context.send(CFG_SERVICE_HTTP_CODES.OK, http.jsonencode(_reportedCfg));
        }
    }

    /**
     * HTTP PATCH request callback function.
     *
     * @param context - Rocky.Context object
     */
    function _patchCfgRockyHandler(context) {
        local newCfg = context.req.body;
        // configuration validate
        if (!_validateCfg(newCfg)) {
            context.send(CFG_SERVICE_HTTP_CODES.INVALID_REQ);
            return;
        }
        local newUpdateId = newCfg.configuration.updateId; 
        ::info("Configuration validated. Update ID: " + 
               newUpdateId, 
               "@{CLASS_NAME}");
        // check new configuration update id
        if (_updateIdIsUniq(newUpdateId)) {
            // save cfg to queue if in queue enough free space
            if (_queuePush(newCfg)) {
                // configuration is added, send 200
                context.send(CFG_SERVICE_HTTP_CODES.OK);
            } else {
                ::error("Sending configuration queue is full", "@{CLASS_NAME}");
                context.send(CFG_SERVICE_HTTP_CODES.TOO_MANY_REQ);
            }
        }
    }

    /**
     *  Search update id in queue.
     * 
     *  @param newUpdateId - update id of incoming configuration.
     *
     *  @return {boolean} true - new update id is uniq.
     */
    function _updateIdIsUniq(newUpdateId) {
        foreach (cfg in _sendingCfgs) {
            local findRes = cfg.configuration.updateId.find(newUpdateId); 
            if (findRes != null) {
                // ::debug("_updateIdIsUniq " + findRes, "@{CLASS_NAME}");
                return false;
            }
        }

        return true;
    }

    /**
     *  Push new configuration to queue.
     *
     *  @param {table} newCfg - configuration for sending to Imp-device.
     *
     *  @return {boolean} true - new configuration is append.
     */
    function _queuePush(newCfg) {
        local appendToQueue = false;
        if (_sendingCfgs.len() < CFG_SERVICE_MAX_COUNT_SENDING_CFG) {
            ::debug("Push new cfg", "@{CLASS_NAME}");
            _sendingCfgs.append(newCfg);
            appendToQueue = true;
            if (null == _timerQueue) {
                _timerQueue = imp.wakeup(0, _queueScheduler.bindenv(this));
            }
        }

        return appendToQueue;
    }

    /**
     * Configuration queue scheduler.
     */
    function _queueScheduler() {
        if (_sendingCfgs.len() > 0 || _currentSendingCfg != null) {
            if (_currentSendingCfg == null) {
                _currentSendingCfg = _sendingCfgs.pop();
            }
            if (device.isconnected()) {
                _msngr.send(APP_RM_MSG_NAME.CFG, _currentSendingCfg);
            } else {
                _isPendingCfg = true;
                // If there was another pending cfg, it is overwritten by the new one
                if (_sendingCfgs.len() > 0) {
                    _sendingCfgs.reverse();
                    _currentSendingCfg = _sendingCfgs.pop();
                    _sendingCfgs.clear();
                }
                _pendingUpdateId = _currentSendingCfg.configuration.updateId;
                _timerQueue = imp.wakeup(CFG_SERVICE_CHECK_IMP_CONNECT_TIMEOUT, 
                                         _queueScheduler.bindenv(this));
            }
        }
    }

    /**
     * Handler for configuration received from Imp-Device
     */
    function _cfgCb(msg, ackData) {
        ::debug("Cfg received from imp-device, msgId = " + msg.id, "@{CLASS_NAME}");
        // saves it as reported cfg
        _reportedCfg = msg.data;
    }

    /**
     * Callback that is triggered when a message is acknowledged.
     */
    function _ackCb(msg, ackData) {
       ::debug("Ack cfg", "@{CLASS_NAME}");
       _lastCfgUpdAplTime = time();
       _currentSendingCfg = null;
       _isPendingCfg = false;
       _pendingUpdateId = null;
       if (_sendingCfgs.len() > 0) {
           _timerQueue = imp.wakeup(CFG_SERVICE_CHECK_IMP_CONNECT_TIMEOUT, 
                                    _queueScheduler.bindenv(this));
       } else {
           _timerQueue = null;
       }
    }

    /**
     * Callback that is triggered when a message sending fails.
     */
    function _failCb(msg, error) {
        ::debug("Fail cfg", "@{CLASS_NAME}");
        _timerQueue = imp.wakeup(CFG_SERVICE_CHECK_IMP_CONNECT_TIMEOUT, 
                                 _queueScheduler.bindenv(this));
    }

    /**
     * Check and set agent log level
     *
     * @param {table} logLevels - Table with the agent log level value.
     *        The table fields:
     *          "agentLogLevel": {string} Log level ("ERROR", "INFO", "DEBUG")
     *
     * @return {boolean} true - set log level success.
     */
    function _checkAndSetLogLevel(logLevels) {
        if ("agentLogLevel" in logLevels) {
            switch (logLevels.agentLogLevel) {
                case "DEBUG":
                case "INFO":
                case "ERROR":
                    ::debug("Set agent log level: " + logLevels.agentLogLevel, "@{CLASS_NAME}");
                    Logger.setLogLevelStr(logLevels.agentLogLevel.tolower());
                    break;
                default:
                    ::error("Unknown log level", "@{CLASS_NAME}");
                    return false;
            }
        }

        return true;
    }

    /**
     * Check availability and value type of the "enable" field.
     *
     * @param {table} cfgGroup - Configuration parameters table.
     *
     * @return {boolean} true - availability and value type admissible.
     */
    function _checkEnableField(cfgGroup) {
        if ("enabled" in cfgGroup) {
            if (typeof(cfgGroup.enabled) != "bool") {
                ::error("Enable field - type mismatch", "@{CLASS_NAME}");
                return false;
            }
        }

        return true;
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
     *          "fixedValues": {array} - Permissible fixed value array (not in [lowLim, highLim]).
     * @param {table} cfgGroup - Table with the configuration parameters.
     *
     * @return {boolean} true - validation success.
     */
    function _rulesCheck(rules, cfgGroup) {
        foreach (rule in rules) {
            local fieldNotExist = true;
            foreach (fieldName, field in cfgGroup) {
                if (rule.name == fieldName) {
                    fieldNotExist = false;
                    if (typeof(field) != rule.validationType) {
                        ::error("Field: "  + fieldName + " - type mismatch", "@{CLASS_NAME}");
                        return false;
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
                                    ::error("Field: "  + fieldName + " - value not in range", "@{CLASS_NAME}");
                                    return false;
                                }
                            } else {
                                ::error("Field: "  + fieldName + " - value not in range", "@{CLASS_NAME}");
                                return false;
                            }
                        }
                    }
                    if ("minLen" in rule && "maxLen" in rule) {
                        local fieldLen = field.len();
                        if (fieldLen < rule.minLen || fieldLen > rule.maxLen) {
                            ::error("Field: "  + fieldName + " - length not in range", "@{CLASS_NAME}");
                            return false;
                        }
                    }
                    if ("minTimeStamp" in rule) {
                        if (field.tointeger() < rule.minTimeStamp.tointeger()) {
                            ::error("Field: "  + fieldName + " - time not in range", "@{CLASS_NAME}");
                            return false;
                        }
                    }
                }
            }
            if (rule.required && fieldNotExist) {
                ::error("Field: "  + fieldName + " - not exist", "@{CLASS_NAME}");
                return false;
            }
        }

        return true;
    }

    /**
     * Validation of the alert parameters.
     *
     * @param {table} alerts - The alerts configuration table.
     *
     * @return {boolean} true - Parameters are correct.
     */
    function _validateAlerts(alerts) {
        foreach (alertName, alert in alerts) {
            local validationRules = [];
            // check enable field
            if (!_checkEnableField(alert)) return false;
            // check other fields
            switch (alertName) {
                case "batteryLow": 
                    // charge level [0;100] %
                    validationRules.append({"name":"threshold",
                                            "required":true,
                                            "validationType":"float", 
                                            "lowLim":0.0, 
                                            "highLim":100.0});
                    break;
                case "temperatureLow":
                case "temperatureHigh":
                    // industrial temperature range
                    validationRules.append({"name":"threshold",
                                            "required":true,
                                            "validationType":"float", 
                                            "lowLim":-40.0, 
                                            "highLim":85.0});
                    validationRules.append({"name":"hysteresis",
                                            "required":true,
                                            "validationType":"float", 
                                            "lowLim":0.0, 
                                            "highLim":10.0});
                    break;
                case "shockDetected":
                    // LIS2DH12 maximum shock threshold - 16 g
                    validationRules.append({"name":"threshold",
                                            "required":true,
                                            "validationType":"float", 
                                            "lowLim":CFG_SERVICE_SHOCK_ACC_SAFEGUARD_MIN, 
                                            "highLim":CFG_SERVICE_SHOCK_ACC_SAFEGUARD_MAX});
                    break;
                case "tamperingDetected":
                default:
                    break;
            }
            // rules checking
            if (!_rulesCheck(validationRules, alert)) return false;
        }

        // check low < high temperature
        if ("temperatureLow" in alerts && 
            "temperatureHigh" in alerts) {
            if (alerts.temperatureLow.threshold >= 
                alerts.temperatureHigh.threshold) {
                return false;
            }
        }

        return true;
    }

    /**
     * Validation of individual fields.
     *
     * @param {table} conf - Configuration table.
     *
     * @return {boolean} true - Parameters are correct.
     */
    function _validateIndividualField(conf) {

        local validationRules = [];
        validationRules.append({"name":"connectingPeriod",
                                "required":true,
                                "validationType":"float", 
                                "lowLim":CFG_SERVICE_CONNECTING_SAFEGUARD_MIN, 
                                "highLim":CFG_SERVICE_CONNECTING_SAFEGUARD_MAX});
        validationRules.append({"name":"readingPeriod",
                                "required":true,
                                "validationType":"float", 
                                "lowLim":CFG_SERVICE_READING_SAFEGUARD_MIN, 
                                "highLim":CFG_SERVICE_READING_SAFEGUARD_MAX});
        validationRules.append({"name":"updateId",
                                "required":true,
                                "validationType":"string",
                                "minLen":1,
                                "maxLen":150});
        if (!_rulesCheck(validationRules, conf)) return false;

        return true;
    }

    /**
     * Validation of the BLE device configuration.
     * 
     * @param {table} bleDevices - Generic BLE device configuration table.
     *
     * @return {boolean} - true - validation success.
     */
    function _validateGenericBLE(bleDevices) {
        const BLE_MAC_ADDR = @"(?:\x\x){5}\x\x";
        foreach (bleDeviveMAC, bleDevive  in bleDevices) {
            local regex = regexp(format(@"^%s$", BLE_MAC_ADDR));
            local regexCapture = regex.capture(bleDeviveMAC);
            if (regexCapture == null) {
                ::error("Generic BLE device MAC address error", "@{CLASS_NAME}");
                return false;
            }
            if (!_rulesCheck(_coordValidationRules, bleDevive)) return false;
        }

        return true;
    }

    /**
     * Validation of the iBeacon configuration.
     * 
     * @param {table} iBeacons - iBeacon configuration table.
     *
     * @return {boolean} - true - validation success.
     */
    function _validateBeacon(iBeacons) {
        const IBEACON_UUID = @"(?:\x\x){15}\x\x";
        const IBEACON_MAJOR_MINOR = @"\d{1,5}";
        foreach (iBeaconUUID, iBeacon in iBeacons) {
            local regex = regexp(format(@"^%s$", IBEACON_UUID));
            local regexCapture = regex.capture(iBeaconUUID);
            if (regexCapture == null) {
                ::error("iBeacon UUID error", "@{CLASS_NAME}");
                return false;
            }
            foreach (majorVal, major in iBeacon) {
                regex = regexp(format(@"^%s$", IBEACON_MAJOR_MINOR));
                regexCapture = regex.capture(majorVal);
                if (regexCapture == null) {
                    ::error("iBeacon major error", "@{CLASS_NAME}");
                    return false;
                }
                // max 2 bytes (65535)
                if (majorVal.tointeger() > 65535) {
                    ::error("iBeacon major error (more then 65535)", "@{CLASS_NAME}");
                    return false;
                }
                foreach (minorVal, minor in major) {
                    regexCapture = regex.capture(minorVal);
                    if (regexCapture == null) {
                        ::error("iBeacon minor error", "@{CLASS_NAME}");
                        return false;
                    }
                    // max 2 bytes (65535)
                    if (minorVal.tointeger() > 65535) {
                        ::error("iBeacon minor error (more then 65535)", "@{CLASS_NAME}");
                        return false;
                    }
                    if (!_rulesCheck(_coordValidationRules, minor)) return false;
                }
            }
        }

        return true;
    }

    /**
     * Validation of the location tracking configuration block.
     * 
     * @param {table} locTracking - Location tracking configuration table.
     *
     * @return {boolean} - true - validation success.
     */
    function _validateLocTracking(locTracking) {

        if ("locReadingPeriod" in locTracking) {
            local validationRules = [];
            validationRules.append({"name":"locReadingPeriod",
                                    "required":true,
                                    "validationType":"float", 
                                    "lowLim":CFG_SERVICE_LOC_READING_SAFEGUARD_MIN, 
                                    "highLim":CFG_SERVICE_LOC_READING_SAFEGUARD_MAX});
            if (!_rulesCheck(validationRules, locTracking)) return false;
        }

        if ("alwaysOn" in locTracking) {
            local validationRules = [];
            validationRules.append({"name":"alwaysOn",
                                    "required":true,
                                    "validationType":"bool"});
            if (!_rulesCheck(validationRules, locTracking)) return false;
        }
        // validate motion monitoring configuration
        if ("motionMonitoring" in locTracking) {
            local validationRules = [];
            local motionMon = locTracking.motionMonitoring;
            // check enable field
            if (!_checkEnableField(motionMon)) return false;
            validationRules.append({"name":"movementAccMin",
                                    "required":true,
                                    "validationType":"float", 
                                    "lowLim":0.1, 
                                    "highLim":4.0});
            validationRules.append({"name":"movementAccMax",
                                    "required":true,
                                    "validationType":"float", 
                                    "lowLim":0.1, 
                                    "highLim":4.0});
            // min 1/ODR (current 100 Hz), max INT1_DURATION - 127/ODR
            validationRules.append({"name":"movementAccDur",
                                    "required":true,
                                    "validationType":"float", 
                                    "lowLim":0.01, 
                                    "highLim":1.27});
            validationRules.append({"name":"motionTime",
                                    "required":true,
                                    "validationType":"float", 
                                    "lowLim":0.01, 
                                    "highLim":3600.0});
            validationRules.append({"name":"motionVelocity",
                                    "required":true,
                                    "validationType":"float", 
                                    "lowLim":0.1, 
                                    "highLim":10.0});
            validationRules.append({"name":"motionDistance",
                                    "required":true,
                                    "validationType":"float", 
                                    "fixedValues":[0.0],
                                    "lowLim":CFG_SERVICE_MOTION_DIST_SAFEGUARD_MIN, 
                                    "highLim":CFG_SERVICE_MOTION_DIST_SAFEGUARD_MAX});
            if (!_rulesCheck(validationRules, motionMon)) return false;
        }

        if ("geofence" in locTracking) {
            local validationRules = [];
            validationRules.extend(_coordValidationRules);
            local geofence = locTracking.geofence;
            // check enable field
            if (!_checkEnableField(geofence)) return false;
            validationRules.append({"name":"radius",
                                    "required":true,
                                    "validationType":"float", 
                                    "lowLim":0.0, 
                                    "highLim":CFG_SERVICE_EARTH_RADIUS});
            if (!_rulesCheck(validationRules, geofence)) return false;
        }

        if ("repossessionMode" in locTracking) {
            local validationRules = [];
            local repossession = locTracking.repossessionMode;
            // check enable field
            if (!_checkEnableField(repossession)) return false;
            validationRules.append({"name":"after",
                                    "required":true,
                                    "validationType":"string", 
                                    "minLen":1,
                                    "maxLen":150,
                                    "minTimeStamp": CFG_SERVICE_MIN_TIMESTAMP});
            if (!_rulesCheck(validationRules, repossession)) return false;
        }

        if ("bleDevices" in locTracking) {
            local validationRules = [];
            local ble = locTracking.bleDevices;
            // check enable field
            if (!_checkEnableField(ble)) return false;
            if ("generic" in ble) {
                local bleDevices = ble.generic;
                if (!_validateGenericBLE(bleDevices)) return false;
            }
            if ("iBeacon" in ble) {
                local iBeacons = ble.iBeacon;
                if (!_validateBeacon(iBeacons)) return false;
            }
        }

        return true;
    }

    /**
     * Validation of the full or partial input configuration.
     * 
     * @param {table} msg - Configuration table.
     *
     * @return {boolean} - true - validation success.
     */
    function _validateCfg(msg) {
        // set log level
        if ("debug" in msg) {
            local debugParam = msg.debug;
            if (!_checkAndSetLogLevel(debugParam)) return false;
        }
        // validate configuration
        if ("configuration" in msg) {
            local conf = msg.configuration;
            if (!_validateIndividualField(conf)) return false;
            // validate alerts
            if ("alerts" in conf) {
                local alerts = conf.alerts;
                if (!_validateAlerts(alerts)) return false;
            }
            // validate location tracking
            if ("locationTracking" in conf) {
                local tracking = conf.locationTracking;
                if (!_validateLocTracking(tracking)) return false;
            }
        } else {
            ::error("Configuration not exist", "@{CLASS_NAME}");
            return false;
        }

        return true;
    }

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
        context.send(CFG_SERVICE_HTTP_CODES.UNAUTHORIZED, { "message": "Unauthorized" });
    }
}

@set CLASS_NAME = null // Reset the variable