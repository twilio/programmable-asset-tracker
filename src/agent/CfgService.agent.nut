@set CLASS_NAME = "CfgService" // Class name for logging

// Username to access the REST API
const CFG_SERVICE_REST_API_USERNAME = "test";
// Password to access the REST API
const CFG_SERVICE_REST_API_PASSWORD = "test";
// API endpoints:
const CFG_SERVICE_REST_API_DATA_ENDPOINT = "/cfg";

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

    /**
     * Constructor for Configuration Service Class
     *
     * @param {object} msngr - Messenger instance
     * @param {object} rocky - Rocky instance
     */
    constructor(msngr, rocky) {
        _msngr = msngr;
        _rocky = rocky;
        // _msngr.onAck(_onAckCb.bindenv(this));
        // _msngr.onFail(_onFailCb.bindenv(this));

        _authHeader = "Basic " + http.base64encode(CFG_SERVICE_REST_API_USERNAME + ":" + CFG_SERVICE_REST_API_PASSWORD);
    }

    function init() {
        _rocky.authorize(_authCb.bindenv(this));
        _rocky.onUnauthorized(_unauthCb.bindenv(this));
        _rocky.on("GET", CFG_SERVICE_REST_API_DATA_ENDPOINT, _getCfgRockyHandler.bindenv(this), null);
        _rocky.on("PATCH", CFG_SERVICE_REST_API_DATA_ENDPOINT, _patchCfgRockyHandler.bindenv(this), null);
    }


    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Callback that is triggered when a message is acknowledged.
     */
    function _onAckCb(msg, ackData) {
       
    }

    /**
     * Callback that is triggered when a message sending fails.
     */
    function _onFailCb(msg, error) {
        
    }

    function _getCfgRockyHandler(context) {
        if (_reportedCfg == null) {
            // only description is returned
            ::debug("Only description is returned", "@{CLASS_NAME}");
            local descr = {
                            "trackerId": "",
                            "cfgSchemeVersion": "1.1",
                            "cfgTimestamp": _lastCfgUpdAplTime,
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

    function _checkAndSetLogLevel(msg) {
        if ("debug" in msg) {
            if ("agentLogLevel" in msg.debug) {
                switch (msg.debug.agentLogLevel) {
                    case "DEBUG":
                    case "INFO":
                    case "ERROR":
                        ::debug("Set agent log level: " + msg.debug.agentLogLevel, "@{CLASS_NAME}");
                        Logger.setLogLevelStr(msg.debug.agentLogLevel.tolower());
                        break;
                    default:
                        ::error("Unknown log level", "@{CLASS_NAME}");
                        break;
                }
            }
        }
    }

    function _checkEnableField(cfgGroup) {
        if ("enabled" in cfgGroup) {
            if (typeof(cfgGroup.enabled) != "bool") return false;
        }

        return true;
    }

    function _rulesCheck(rules, cfgGroup) {
        foreach (rule in rules) {
            foreach (fieldName, field in cfgGroup) {
                if (rule.name == fieldName) {
                    if (typeof(field) != rule.ruleType) return false;
                    if (field < rule.low || field > rule.high) return false;
                }
            }
        }

        return true;
    }

    function _checkCorrectnessAlerts(alerts) {
        foreach (alertName, alert in alerts) {
            local rules = [];
            // check enable
            if (!_checkEnableField(alert)) return false;
            // check fields
            switch (alertName) {
                case "batteryLow": 
                    // charge level [0;100] %
                    rules.append({"name":"threshold",
                                  "ruleType":"float", 
                                  "low":0.0, 
                                  "high":100.0});
                    break;
                case "temperatureLow":
                case "temperatureHigh":
                    // industrial temperature range
                    rules.append({"name":"threshold",
                                  "ruleType":"float", 
                                  "low":-40.0, 
                                  "high":85.0});
                    rules.append({"name":"hysteresis",
                                  "ruleType":"float", 
                                  "low":0.0, 
                                  "high":10.0});
                    break;
                case "shockDetected":
                    // LIS2DH12 maximum shock threshold - 16 g
                    rules.append({"name":"threshold",
                                  "ruleType":"float", 
                                  "low":0.0, 
                                  "high":16.0});
                    break;
                case "tamperingDetected":
                default:
                    break;
            }
            if (!_rulesCheck(rules, alert)) return false;
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

    function _checkCorrectnessCfg(msg) {
        if ("configuration" in msg) {
            local conf = msg.configuration;
            if ("alerts" in conf) {
                local alerts = conf.alerts;
                if (!_checkCorrectnessAlerts(alerts)) return false;
            }

        } else {
            return false;
        }

        return true;
    } 

    function _patchCfgRockyHandler(context) {
        local body = context.req.body;

        // set log level
        _checkAndSetLogLevel(body);
        // check correctness of configuration
        if (!_checkCorrectnessCfg(body)) {
            context.send(CFG_SERVICE_HTTP_CODES.INVALID_REQ);
            return;
        }

        context.send(CFG_SERVICE_HTTP_CODES.OK);
    }

    function _authCb(context) {
        return (context.getHeader("Authorization") == _authHeader.tostring());
    }

    function _unauthCb(context) {
        context.send(CFG_SERVICE_HTTP_CODES.UNAUTHORIZED, { "message": "Unauthorized" });
    }
}

@set CLASS_NAME = null // Reset the variable