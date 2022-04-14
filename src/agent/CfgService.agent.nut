@set CLASS_NAME = "CfgService" // Class name for logging

// Timeout to re-check connection with imp-device, in seconds
const CFG_CHECK_IMP_CONNECT_TIMEOUT = 10;
// API endpoint
const CFG_REST_API_DATA_ENDPOINT = "/cfg";

// Enum for HTTP codes 
enum CFG_REST_API_HTTP_CODES {
    OK = 200,
    INVALID_REQ = 400,
    UNAUTHORIZED = 401
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
    // Sending timer
    _timerSending = null;
    // Cfg update which is being sent to the imp-device, 
    // also behaves as "sending in process" flag
    _sendingCfg = null;
    // Cfg update which waits for successful delivering to the imp-device
    _pendingCfg = null;

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
                      http.base64encode(__VARS.CFG_REST_API_USERNAME + 
                      ":" + 
                      __VARS.CFG_REST_API_PASSWORD);

        _sendingCfg = null;
        _pendingCfg = null;
        _rocky.authorize(_authCb.bindenv(this));
        _rocky.onUnauthorized(_unauthCb.bindenv(this));
        _rocky.on("GET", 
                  CFG_REST_API_DATA_ENDPOINT, 
                  _getCfgRockyHandler.bindenv(this), 
                  null);
        _rocky.on("PATCH", 
                  CFG_REST_API_DATA_ENDPOINT, 
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
        ::info("GET " + CFG_REST_API_DATA_ENDPOINT + 
               " request from cloud", "@{CLASS_NAME}");

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
            reportToCloud = _reportedCfg;
            reportToCloud.agentConfiguration <- {"debug" : {}};
        } else {
            // No cfg data from the imp-device exists.
            // Add empty "description" and "agentConfiguration" fields.
            reportToCloud = { "description": {},
                              "agentConfiguration" : {"debug" : {}} };
            ::info("No cfg data from imp-device is available", "@{CLASS_NAME}");
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
            reportToCloud.description.pendingUpdateId <- _pendingCfg.configuration.updateId;
        }
        reportToCloud.agentConfiguration.debug.logLevel <- Logger.getLogLevelStr().toupper();

        ::debug("Log full table which to be returned to the cloud: " + 
                http.jsonencode(reportToCloud), "@{CLASS_NAME}");

        // Return the data to the cloud
        context.send(CFG_REST_API_HTTP_CODES.OK, http.jsonencode(reportToCloud));
    }

    /**
     * HTTP PATCH request callback function.
     *
     * @param context - Rocky.Context object
     */
    function _patchCfgRockyHandler(context) {
        local newCfg = context.req.body;
        // configuration validate
        local validateCfgRes = validateCfg(newCfg);
        if (validateCfgRes != null) {
            ::error(validateCfgRes, "@{CLASS_NAME}");
            context.send(CFG_REST_API_HTTP_CODES.INVALID_REQ, 
                         validateCfgRes);
            return;
        }
        ::info("Configuration validated.", "@{CLASS_NAME}");
        // applying configuration
        _applyAgentCfg(newCfg);
        // send configuration to device if exist
        if ("configuration" in newCfg) {
            local newUpdateId = newCfg.configuration.updateId; 
            ::info("Update ID: " + 
                   newUpdateId, 
                   "@{CLASS_NAME}");
            // Pending cfg is always overwritten by the new cfg update
            _pendingCfg = newCfg.configuration;
            if (_sendingCfg == null) {
                // If another sending process is not in progress, 
                // then start the sending process
                _sendCfg();
            }
        }
        // configuration is added, send 200
        context.send(CFG_REST_API_HTTP_CODES.OK);
    }

    /**
     * Applying configuration.
     *
     * @param {table} cfg - Configuration table.
     */
    function _applyAgentCfg(cfg) {
        if ("agentConfiguration" in cfg) {
            if ("debug" in cfg.agentConfiguration) {
                local storedAgentData = server.load();
                local logLevel = cfg.agentConfiguration.debug.logLevel.tolower();

                ::info("Imp-agent log level is set to \"" + logLevel + "\"");
                Logger.setLogLevelStr(logLevel);

                storedAgentData.rawset("deploymentId", __EI.DEPLOYMENT_ID);
                storedAgentData.rawset("agentLogLevel", logLevel);
                try {
                    server.save(storedAgentData);
                } catch (exp) {
                    ::error("Can not save logging settings in the persistent memory: " + 
                            exp, 
                            "@{CLASS_NAME}");
                }
            }
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
                // Device is disconnected
                _timerSending && imp.cancelwakeup(_timerSending);
                // Try the sending again
                _timerSending = imp.wakeup(CFG_CHECK_IMP_CONNECT_TIMEOUT, 
                                           _sendCfg.bindenv(this));
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
        local name = msg.payload.name;
        ::debug("Ack, name: " + name, "@{CLASS_NAME}");
        if (name.find(APP_RM_MSG_NAME.CFG) != null && 
            name.len() == APP_RM_MSG_NAME.CFG.len()) {
            if (_pendingCfg == _sendingCfg) {
                 // There was no new cfg request during the sending process
                 // => no pending cfg anymore (till the next cfg patch request)
                 _pendingCfg = null;
            }
            // Sending process is completed
            _sendingCfg = null;
            // Send the next cfg update, if there is any
            _sendCfg();
        }
    }

    /**
     * Callback that is triggered when a message sending fails.
     */
    function _failCb(msg, error) {
        local name = msg.payload.name;
        ::debug("Fail, name: " + name, "@{CLASS_NAME}");
        if (name.find(APP_RM_MSG_NAME.CFG) != null && 
            name.len() == APP_RM_MSG_NAME.CFG.len()) {
            // Send/resend the cfg update:
            //   - if there was a new cfg request => send it
            //   - else => resend the failed one
            _sendCfg();
        }
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
        context.send(CFG_REST_API_HTTP_CODES.UNAUTHORIZED, 
                     { "message": "Unauthorized" });
    }
}

@set CLASS_NAME = null // Reset the variable