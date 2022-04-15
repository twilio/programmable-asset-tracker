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
// Server.flush timeout (sec)
const PMGR_FLUSH_TIMEOUT = 5;

// Implements useful in production features:
// - Emergency mode (If an unhandled error occurred, device goes to sleep and periodically connects to the server waiting for a SW update)
// - Shipping mode (When released from the factory, the device sleeps until it is woken up by the end-user) (NOT IMPLEMENTED)
class ProductionManager {
    _debugOn = false;
    _startAppFunc = null;
    _isNewDeployment = false;

    /**
     * Constructor for Production Manager
     *
     * @param {function} startAppFunc - The function to be called to start the main application
     */
    constructor(startAppFunc) {
        _startAppFunc = startAppFunc;
    }

    /**
     * Start the manager. It will check the conditions and either start the main application or go to sleep
     */
    function start() {
        // TODO: Erase the flash memory on first start (when awake from shipping mode)? Or in factory code?

        // NOTE: The app may override this handler but it must call enterEmergencyMode in case of a runtime error
        imp.onunhandledexception(_onUnhandledException.bindenv(this));

        local userConf = _readUserConf();
        local data = _extractDataFromUserConf(userConf);

        if (data && data.lastError != null) {
            // TODO: Improve logging!
            _printLastError(data.lastError);
        }

        if (data && data.errorFlag && data.deploymentID == __EI.DEPLOYMENT_ID) {
            if (server.isconnected()) {
                // No new deployment was detected
                _sleep();
            } else {
                // Connect to check for a new deployment
                server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, 30);
                server.connect(_sleep.bindenv(this), PMGR_CONNECT_TIMEOUT);
            }
            return;
        } else if (!data || data.deploymentID != __EI.DEPLOYMENT_ID) {
            _info("New deployment detected!");
            _isNewDeployment = true;
            userConf[PMGR_USER_CONFIG_FIELD] <- _initialUserConfData();
            _storeUserConf(userConf);
        }

        _startAppFunc();
    }

    /**
     * Manually enter the Emergency mode
     *
     * @param {string} [error] - The error that caused entering the Emergency mode
     */
    function enterEmergencyMode(error = null) {
        _setErrorFlag(error);
        server.flush(PMGR_FLUSH_TIMEOUT);
        server.restart();
    }

    // TODO: Comment
    function isNewDeployment() {
        return _isNewDeployment;
    }

    /**
     * Turn on/off the debug logging
     *
     * @param {boolean} value - True to turn on the debug logging, otherwise false
     */
    function setDebug(value) {
        _debugOn = value;
    }

    /**
     * Print the last saved error
     *
     * @param {table} lastError - Last saved error with timestamp and description
     */
    function _printLastError(lastError) {
        if ("ts" in lastError && "desc" in lastError) {
            _info(format("Last error (at %d): \"%s\"", lastError.ts, lastError.desc));
        }
    }

    /**
     * Go to sleep once Squirrel VM is idle
     */
    function _sleep(unusedParam = null) {
        imp.onidle(function() {
            server.sleepfor(PMGR_CHECK_UPDATES_PERIOD);
        });
    }

    /**
     * Global handler for exceptions
     *
     * @param {string} error - The exception description
     */
    function _onUnhandledException(error) {
        _error("Globally caught error: " + error);
        _setErrorFlag(error);
    }

    /**
     * Create and return the initial user configuration data
     *
     * @return {table} The initial user configuration data
     */
    function _initialUserConfData() {
        return {
            "errorFlag": false,
            "lastError": null,
            "deploymentID": __EI.DEPLOYMENT_ID
        };
    }

    /**
     * Set the error flag which will restrict running the main application on the next boot
     *
     * @param {string} error - The error description
     */
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

    /**
     * Store the user configuration
     *
     * @param {table} userConf - The table to be converted to JSON and stored
     */
    function _storeUserConf(userConf) {
        local dataStr = JSONEncoder.encode(userConf);
        _debug("Storing new user configuration: " + dataStr);

        try {
            imp.setuserconfiguration(dataStr);
        } catch (err) {
            _error(err);
        }
    }

    /**
     * Read the user configuration
     *
     * @return {table} The user configuration converted from JSON to a Squirrel table
     */
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

    /**
     * Extract and check the data belonging to Production Manager from the user configuration
     *
     * @param {table} userConf - The user configuration
     *
     * @return {table|null} The data extracted or null
     */
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

    /**
     * Log a debug message if debug logging is on
     *
     * @param {string} msg - The message to log
     */
    function _debug(msg) {
        _debugOn && server.log("[@{CLASS_NAME}] " + msg);
    }

    /**
     * Log an info message
     *
     * @param {string} msg - The message to log
     */
    function _info(msg) {
        server.log("[@{CLASS_NAME}] " + msg);
    }

    /**
     * Log an error message
     *
     * @param {string} msg - The message to log
     */
    function _error(msg) {
        server.error("[@{CLASS_NAME}] " + msg);
    }
}

@set CLASS_NAME = null // Reset the variable
