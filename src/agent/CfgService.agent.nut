@set CLASS_NAME = "CfgService" // Class name for logging

// API endpoint
const CFG_SERVICE_REST_API_DATA_ENDPOINT = "/cfg";

// Enum for HTTP codes 
enum CFG_SERVICE_HTTP_CODES {
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
    // Pending configuration Id
    _pendingUpdateId = null;
    // Pending configuration flag
    _isDisconnected = null;
    // Sending timer
    _timerSending = null;
    // Sending configuration
    _sendingCfg = null;
    // Pending configuration
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

        _isDisconnected = false;
        _authHeader = "Basic " + 
                      http.base64encode(__VARS.CFG_SERVICE_REST_API_USERNAME + 
                      ":" + 
                      __VARS.CFG_SERVICE_REST_API_PASSWORD);
    }

    /**
     * Set Rocky callback functions.
     */
    function init() {
        _sendingCfg = null;
        _pendingCfg = null;
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
                          "cfgSchemeVersion": CFG_SCHEME_VERSION
                      };
        if (_isDisconnected) {
            descr["pendingUpdateId"] <- _pendingUpdateId;
        }
        if (_reportedCfg == null) {
            // only description is returned
            ::debug("Only description is returned", "@{CLASS_NAME}");
            context.send(CFG_SERVICE_HTTP_CODES.OK, http.jsonencode(descr));
        } else {
            _reportedCfg.description["trackerId"] <- imp.configparams.deviceid;
            _reportedCfg.description["cfgSchemeVersion"] <- CFG_SCHEME_VERSION;
            if (_isDisconnected) {
                _reportedCfg.description["pendingUpdateId"] <- _pendingUpdateId;
            }
            // Returns reported configuration
            ::debug("Return reported configuration", "@{CLASS_NAME}");
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
        if (!validateCfg(newCfg)) {
            context.send(CFG_SERVICE_HTTP_CODES.INVALID_REQ);
            return;
        }
        ::info("Configuration validated.", "@{CLASS_NAME}");
        // applying configuration
        _applyCfg(newCfg);
        // send configuration to device if exist
        if ("configuration" in newCfg) {
            local newUpdateId = newCfg.configuration.updateId; 
            ::info("Update ID: " + 
                   newUpdateId, 
                   "@{CLASS_NAME}");
            _pendingCfg = newCfg;
            if (_sendingCfg == null) _sendCfg();
        }
        // configuration is added, send 200
        context.send(CFG_SERVICE_HTTP_CODES.OK);
    }

    /**
     * Applying configuration.
     *
     * @param {table} cfg - Configuration table.
     */
    function _applyCfg(cfg) {
        if ("debug" in cfg) {
            if ("agentLogLevel" in cfg.debug) {
                local storedAgentData = server.load();
                local logLevel = cfg.debug.agentLogLevel.tolower();
                storedAgentData.rawset("deploymentId", __EI.DEPLOYMENT_ID);
                storedAgentData.rawset("agentLogLevel", logLevel);
                try {
                    server.save(storedAgentData);
                } catch (exp) {
                    ::error("Can not save logging settings in the persistent memory: " + 
                            exp, 
                            "@{CLASS_NAME}");
                }
                Logger.setLogLevelStr(logLevel);
            }
        }
    }

    /**
     * Send configuration to device.
     */
    function _sendCfg() {
        if (_pendingCfg != null) {
            _sendingCfg = _pendingCfg;
            if (device.isconnected()) {
                _pendingCfg = null;
                _msngr.send(APP_RM_MSG_NAME.CFG, _sendingCfg);
            } else {
                _isDisconnected = true;
                _pendingUpdateId = _pendingCfg.configuration.updateId;
                _timerSending && imp.cancelwakeup(_timerSending);
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
       ::debug("Ack cfg", "@{CLASS_NAME}");
       _isDisconnected = false;
       _sendingCfg = null;
       _pendingUpdateId = null;
       _sendCfg();
    }

    /**
     * Callback that is triggered when a message sending fails.
     */
    function _failCb(msg, error) {
        ::debug("Fail cfg", "@{CLASS_NAME}");
        if (_pendingCfg == null) _pendingCfg = _sendingCfg;
        _sendCfg();
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