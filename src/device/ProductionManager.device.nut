@set CLASS_NAME = "ProductionManager" // Class name for logging

// ProductionManager's user config field
const PMGR_USER_CONFIG_FIELD = "ProductionManager";
// Period (sec) of checking for new deployments
const PMGR_CHECK_UPDATES_PERIOD = 10;
// Maximum length of stats arrays
const PMGR_STATS_MAX_LEN = 10;
// Maximum length of error saved when error flag is set
const PMGR_MAX_ERROR_LEN = 512;
// Connection timeout (sec)
const PMGR_CONNECT_TIMEOUT = 240;


class ProductionManager {
    _debugOn = false;
    _startAppFunc = null;

    constructor(startAppFunc) {
        _startAppFunc = startAppFunc;
    }

    function start() {
        // NOTE: The app may override this handler but it must call enterEmergencyMode in case of a runtime error
        imp.onunhandledexception(_onUnhandledException.bindenv(this));

        local userConf = _readUserConf();
        local data = _extractDataFromUserConf(userConf);

        if (data == null) {
            _startAppFunc();
            return;
        }

        if (data.lastError != null) {
            _printLastError(data.lastError);
        }

        if (data.errorFlag && data.deploymentID == __EI.DEPLOYMENT_ID) {
            if (server.isconnected()) {
                // No new deployment was detected
                _sleep();
            } else {
                // Connect to check for a new deployment
                server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 30);
                server.connect(_sleep.bindenv(this), PMGR_CONNECT_TIMEOUT);
            }
            return;
        } else if (data.deploymentID != __EI.DEPLOYMENT_ID) {
            _info("New deployment detected!");
            userConf[PMGR_USER_CONFIG_FIELD] <- _initialUserConfData();
            _storeUserConf(userConf);
        }

        _startAppFunc();
    }

    function enterEmergencyMode(error = null) {
        _setErrorFlag(error);
        server.restart();
    }

    function setDebug(value) {
        _debugOn = value;
    }

    function _printLastError(lastError) {
        if ("ts" in lastError && "desc" in lastError) {
            _info(format("Last error (at %d): \"%s\"", lastError.ts, lastError.desc));
        }
    }

    function _sleep(unusedParam = null) {
        imp.onidle(function() {
            server.sleepfor(PMGR_CHECK_UPDATES_PERIOD);
        });
    }

    function _onUnhandledException(error) {
        _error("Globally caught error: " + error);
        _setErrorFlag(error);
    }

    function _initialUserConfData() {
        return {
            "errorFlag": false,
            "lastError": null,
            "deploymentID": __EI.DEPLOYMENT_ID
        };
    }

    function _setErrorFlag(error) {
        local userConf = _readUserConf();
        // If not null, this is just a pointer to the field of userConf. Hence modification of this object updates the userConf object
        local data = _extractDataFromUserConf(userConf);

        if (data == null) {
            // Initialize ProductionManager's user config data
            data = _initialUserConfData();
            userConf[PMGR_USER_CONFIG_FIELD] <- data;
        }

        // By this update we update the userConf object (see above)
        data.errorFlag = true;

        if (typeof(error) == "string") {
            if (error.len() > PMGR_MAX_ERROR_LEN) {
                error = error.slice(0, PMGR_MAX_ERROR_LEN);
            }

            data.lastError = {
                "ts": time(),
                "desc": error
            };
        }

        _storeUserConf(userConf);
    }

    function _storeUserConf(userConf) {
        local dataStr = JSONEncoder.encode(userConf);
        _debug("Storing new user configuration: " + dataStr);

        try {
            imp.setuserconfiguration(dataStr);
        } catch (err) {
            _error(err);
        }
    }

    function _readUserConf() {
        local config = imp.getuserconfiguration();

        if (config == null) {
            _debug("User configuration is empty");
            return {};
        }

        config = config.tostring();
        // TODO: What if a non-readable string was written? It will be printed "binary: ..."
        _debug("User configuration: " + config);

        try {
            config = JSONParser.parse(config);

            if (typeof config != "table") {
                throw "table expected";
            }
        } catch (e) {
            _error("Error during parsing user configuration: " + e);
            return {};
        }

        return config;
    }

    function _extractDataFromUserConf(userConf) {
        try {
            local data = userConf[PMGR_USER_CONFIG_FIELD];

            if ("errorFlag" in data &&
                "lastError" in data &&
                "deploymentID" in data) {
                return data;
            }
        } catch (err) {
        }

        return null;
    }

    function _debug(msg) {
        _debugOn && server.log("[@{CLASS_NAME}] " + msg);
    }

    function _info(msg) {
        server.log("[@{CLASS_NAME}] " + msg);
    }

    function _error(msg) {
        server.error("[@{CLASS_NAME}] " + msg);
    }
}

@set CLASS_NAME = null // Reset the variable
