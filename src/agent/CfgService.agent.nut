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
const CFG_SERVICE_SHOCK_ACC_SAFEGUARD_MIN = 0;
// Maximal shock acceleration alert threshold, in g.
const CFG_SERVICE_SHOCK_ACC_SAFEGUARD_MAX = 16.0;
// How often the tracker connects to network (minimal value), in seconds.
const CFG_SERVICE_CONNECTING_SAFEGUARD_MIN = 0;
// How often the tracker connects to network (maximal value), in seconds.
const CFG_SERVICE_CONNECTING_SAFEGUARD_MAX = 0;
// How often the tracker polls various data (minimal value), in seconds.
const CFG_SERVICE_READING_SAFEGUARD_MIN = 0;
// How often the tracker polls various data (maximal value), in seconds.
const CFG_SERVICE_READING_SAFEGUARD_MAX = 0;
// Minimal distance to determine motion detection condition, in meters.
const CFG_SERVICE_MOTION_DIST_SAFEGUARD_MIN = 0;
// Minimal distance to determine motion detection condition, in meters.
const CFG_SERVICE_MOTION_DIST_SAFEGUARD_MAX = 0;

// Enum for HTTP codes 
enum CFG_SERVICE_HTTP_CODES {
    OK = 200,
    INVALID_REQ = 400,
    UNAUTHORIZED = 401
};

class CfgService {
    // Messenger instance
    _msngr = null;
    // Rocky instance
    _rocky = null;
    //
    _authHeader = null;
    // Reported configuration
    _reportedCfg = null;
    // Latest configuration applied time
    _lastCfgUpdAplTime = null;
    // Pending configuration Id
    _pendingUpdateId = null;
    //
    _isPendingCfg = null;
    // device online check timer
    _sendMsgTimer = null;
    // sending configuration
    _sendingCfg = null;

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

        _authHeader = "Basic " + 
                      http.base64encode(CFG_SERVICE_REST_API_USERNAME + 
                      ":" + 
                      CFG_SERVICE_REST_API_PASSWORD);
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
     * @param context - Rocky.Context object
     */
    function _getCfgRockyHandler(context) {
        if (_reportedCfg == null) {
            // only description is returned
            ::debug("Only description is returned", "@{CLASS_NAME}");
            local descr = {
                            "trackerId": imp.configparams.deviceid,
                            "cfgSchemeVersion": "1.1"
                          };
            if (_isPendingCfg) {
                descr["pendingUpdateId"] <- _pendingUpdateId;
            }
            context.send(CFG_SERVICE_HTTP_CODES.OK, http.jsonencode(descr));
        } else {
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
        // configuration is valid, send 200
        context.send(CFG_SERVICE_HTTP_CODES.OK);
        // send new configuration to device
        _sendingCfg = newCfg;
        _sendMessage();
    }

    /**
     * Sends a message to imp-device, only when imp-device is connected
     *
     * @param {Boolean} repeated - True when called by timer from the wakeup function, otherwise False
     */
    function _sendMessage(repeated = false) {
        if (device.isconnected()) {
            if (repeated) {
                ::info("Imp-Device is back online", "@{CLASS_NAME}");
            }
            if (_sendMsgTimer != null) {
                imp.cancelwakeup(_sendMsgTimer);
                _sendMsgTimer = null;
            }
            // Send messages (if any) which wait for connection
            if (_sendingCfg) {
                _msngr.send(APP_RM_MSG_NAME.CFG, _sendingCfg);
            //     _mcuMsgId = _msngr.send(_mcuMsgToSend.name, _mcuMsgToSend.data).payload.id;
            //     _mcuMsgToSend = null;
            }
        } else {
            _isPendingCfg = true;
            // Imp-device is disconnected
            if (_sendMsgTimer == null || repeated) {
                // Periodically repeat checking the connection till imp-device becomes online
                _sendMsgTimer = imp.wakeup(CFG_SERVICE_CHECK_IMP_CONNECT_TIMEOUT, function() {
                                    _sendMessage(true);
                                }.bindenv(this));

                if (!repeated) {
                    ::info("Imp-Device is offline. Waiting for connection.", "@{CLASS_NAME}");
                }
            }
        }
    }

    /**
     * Handler for Cfg received from Imp-Device
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
    }

    /**
     * Callback that is triggered when a message sending fails.
     */
    function _failCb(msg, error) {
        ::debug("Fail cfg", "@{CLASS_NAME}");
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
            if (typeof(cfgGroup.enabled) != "bool") return false;
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
     * @param {table} cfgGroup - Table with the configuration parameters.
     *
     * @return {boolean} true - validation success.
     */
    function _rulesCheck(rules, cfgGroup) {
        foreach (rule in rules) {
            foreach (fieldName, field in cfgGroup) {
        //         if (rule.name == fieldName) {
        //             if (typeof(field) != rule.ruleType) return false;
        //             if ("low" in rule && "high" in rule) {
        //                 if (field < rule.low || field > rule.high) return false;
        //             }
        //         }
            }
        }

        return true;
    }

    /**
     * Check correctness of alert parameters
     *
     * @param {table} alerts - The alerts table.
     *
     * @return {boolean} true - Parameters are correct.
     */
    function _checkCorrectnessAlerts(alerts) {
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
     * Check correctness of alert parameters.
     *
     * @param {table} alerts - The alerts table.
     *
     * @return {boolean} true - Parameters are correct.
     */
    function _checkCorrectnessIndividualField(conf) {

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

    function _checkCorrectnessLocTracking(locTracking) {

        if ("motionMonitoring" in locTracking) {
            local validationRules = [];
            local motionMon = locTracking.motionMonitoring;
            // check enable field
            if (!_checkEnableField(motionMon)) return false;
            validationRules.append({"name":"movementAccMin",
                                    "required":true,
                                    "validationType":"float", 
                                    "lowLim":0.0, 
                                    "highLim":36000.0});
            validationRules.append({"name":"movementAccMax",
                                    "required":true,
                                    "validationType":"float", 
                                    "lowLim":0.0, 
                                    "highLim":36000.0});
            validationRules.append({"name":"movementAccDur",
                                    "required":true,
                                    "validationType":"float", 
                                    "lowLim":0.0, 
                                    "highLim":36000.0});
            validationRules.append({"name":"motionTime",
                                    "required":true,
                                    "validationType":"float", 
                                    "lowLim":0.0, 
                                    "highLim":36000.0});
            validationRules.append({"name":"motionVelocity",
                                    "required":true,
                                    "validationType":"float", 
                                    "lowLim":0.0, 
                                    "highLim":36000.0});
            
            validationRules.append({"name":"motionDistance",
                                    "required":true,
                                    "validationType":"float", 
                                    "lowLim":0.0, // CFG_SERVICE_MOTION_DIST_SAFEGUARD_MIN
                                    "highLim":CFG_SERVICE_MOTION_DIST_SAFEGUARD_MAX});
             if (!_rulesCheck(validationRules, motionMon)) return false;
        }

        if ("geofence" in locTracking) {
            local validationRules = [];
            local geofence = locTracking.geofence;
            if (!_checkEnableField(geofence)) return false;

        }

        if ("repossessionMode" in locTracking) {

        }

        return true;
    }

    function _validateCfg(msg) {
        // set log level
        if ("debug" in msg) {
            local debugParam = msg.debug;
            if (!_checkAndSetLogLevel(debugParam)) return false;
        }
        if ("configuration" in msg) {
            local conf = msg.configuration;
            if (!_checkCorrectnessIndividualField(conf)) return false;
            if ("alerts" in conf) {
                local alerts = conf.alerts;
                if (!_checkCorrectnessAlerts(alerts)) return false;
            }
            if ("locationTracking" in conf) {
                local tracking = conf.locationTracking;
                if (!_checkCorrectnessLocTracking(tracking)) return false;
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
     * @param context - Rocky.Context object
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