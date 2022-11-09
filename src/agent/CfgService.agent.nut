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

@set CLASS_NAME = "CfgService" // Class name for logging

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
            ::error("Initialization failure: " + err, "@{CLASS_NAME}");
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

        ::info("JSON Cfg Scheme Version: " + CFG_SCHEME_VERSION, "@{CLASS_NAME}");
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
        ::debug("Cfg received from imp-device, msgId = " + msg.id, "@{CLASS_NAME}");
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
        ::info("GET " + CFG_REST_API_DATA_ENDPOINT + " request from cloud", "@{CLASS_NAME}");

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
            reportToCloud.description.pendingUpdateId <- _pendingCfg.updateId;
        }
        reportToCloud.agentConfiguration <- _agentCfg;

        ::debug("Cfg reported to cloud: " + http.jsonencode(reportToCloud), "@{CLASS_NAME}");

        // Return the data to the cloud
        context.send(CFG_REST_API_HTTP_CODES.OK, http.jsonencode(reportToCloud));
    }

    /**
     * HTTP PATCH request callback function.
     *
     * @param context - Rocky.Context object
     */
    function _patchCfgRockyHandler(context) {
        ::info("PATCH " + CFG_REST_API_DATA_ENDPOINT + " request from cloud", "@{CLASS_NAME}");

        local newCfg = context.req.body;

        // validate received cfg update
        local validateCfgRes = validateCfg(newCfg);
        if (validateCfgRes != null) {
            ::error(validateCfgRes, "@{CLASS_NAME}");
            context.send(CFG_REST_API_HTTP_CODES.INVALID_REQ,
                         validateCfgRes);
            return;
        }
        ::debug("Configuration validated.", "@{CLASS_NAME}");

        // apply imp-agent part of cfg if any
        ("agentConfiguration" in newCfg) && _applyAgentCfg(newCfg.agentConfiguration);

        // process imp-device part of cfg, if any
        if ("configuration" in newCfg) {
            // Pending cfg is always overwritten by the new cfg update
            _pendingCfg = newCfg.configuration;
            ::info("Cfg update is pending sending to device, updateId: " +
                   _pendingCfg.updateId, "@{CLASS_NAME}");
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

            ::info("Imp-agent log level is set to \"" + logLevel + "\"", "@{CLASS_NAME}");
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
            ::error("Can't save agent cfg in the persistent memory: " + err, "@{CLASS_NAME}");
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
        ::debug("Fail, name: " + name + ", error: " + error, "@{CLASS_NAME}");
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
        ::debug("Ack, name: " + name, "@{CLASS_NAME}");
        if (name == APP_RM_MSG_NAME.CFG) {
            if (_pendingCfg == _sendingCfg) {
                 // There was no new cfg request during the sending process
                 // => no pending cfg anymore (till the next cfg patch request)
                 _pendingCfg = null;
            }
            // Sending process is completed
            ::info("Cfg update successfully sent to device, updateId: " +
                   _sendingCfg.updateId, "@{CLASS_NAME}");
            _sendingCfg = null;
            // Send the next cfg update, if there is any
            _sendCfg();
        }
    }
}

@set CLASS_NAME = null // Reset the variable
