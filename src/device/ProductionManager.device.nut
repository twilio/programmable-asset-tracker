@set CLASS_NAME = "ProductionManager" // Class name for logging

// ProductionManager's user config field
const PMGR_USER_CONFIG_FIELD = "ProductionManager";
// Period (sec) of checking for new deployments
const PMGR_CHECK_UPDATES_PERIOD = @{PMGR_CHECK_UPDATES_PERIOD || 3600};
// Maximum length of error saved when error flag is set
const PMGR_MAX_ERROR_LEN = 512;
// Connection timeout (sec)
const PMGR_CONNECT_TIMEOUT = 240;
// Server.flush timeout (sec)
const PMGR_FLUSH_TIMEOUT = 5;
// Send timeout for server.setsendtimeoutpolicy() (sec)
const PMGR_SEND_TIMEOUT = 3;

// Implements useful in production features:
// - Emergency mode (If an unhandled error occurred, device goes to sleep and periodically connects to the server waiting for a SW update)
// - Shipping mode (When released from the factory, the device sleeps until it is woken up by the end-user)
class ProductionManager {
    _debugOn = false;
    _startApp = null;
    _shippingMode = false;
    _isNewDeployment = false;

    /**
     * TODO: Update comment
     * Constructor for Production Manager
     *
     * @param {function} startAppFunc - The function to be called to start the main application
     * @param {boolean} shippingMode - Enable shipping mode
     */
    constructor(startAppFunc, shippingMode = false) {
        _startApp = @() imp.wakeup(0, startAppFunc);
        _shippingMode = shippingMode;
    }

    /**
     * Start the manager. It will check the conditions and either start the main application or go to sleep.
     * This method must be called first
     */
    function start() {
        // Maximum sleep time (sec) used for shipping mode
        const PMGR_MAX_SLEEP_TIME = 2419198;

        // TODO: Erase the flash memory on first start (when awake from shipping mode)? Or in factory code?

        // NOTE: The app may override this handler but it must call enterEmergencyMode in case of a runtime error
        imp.onunhandledexception(_onUnhandledException.bindenv(this));
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, WAIT_TIL_SENT, PMGR_SEND_TIMEOUT);

        local data = _getOrInitializeData();

        if (data.errorFlag && data.deploymentID == __EI.DEPLOYMENT_ID) {
            if (server.isconnected()) {
                // No new deployment was detected
                _printLastErrorAndSleep(data.lastError);
            } else {
                local onConnect = function(_) {
                    _printLastErrorAndSleep(data.lastError);
                }.bindenv(this);

                // Connect to check for a new deployment
                server.connect(onConnect, PMGR_CONNECT_TIMEOUT);
            }

            return;
        } else if (data.deploymentID != __EI.DEPLOYMENT_ID) {
            // TODO: Is it OK? (the note below)
            // NOTE: The first code deploy will not be recognized as a new deploy!
            _info("New deployment detected!");
            _isNewDeployment = true;
            data = _initialData(!_shippingMode || data.shipped);
            _storeData(data);
        }

        if (_shippingMode && !data.shipped) {
            _info("Shipping mode is ON and the device has not been shipped yet");
            _sleep(PMGR_MAX_SLEEP_TIME);
        } else {
            _startApp();
        }
    }

    // TODO: Comment
    function shipped() {
        local data = _getOrInitializeData();

        if (data.shipped) {
            return;
        }

        _info("The device has just been shipped! Starting the main application..");

        // Set "shipped" flag
        data.shipped = true;
        _storeData(data);

        // If the error flag is active, we should still go to sleep. Otherwise, let's run the app
        if (!data.errorFlag) {
            // Cancel sleep
            imp.onidle(null);
            // Start the main application
            _startApp();
        }
    }

    /**
     * Manually enter the Emergency mode
     *
     * @param {string} [error] - The error that caused entering the Emergency mode
     */
    function enterEmergencyMode(error = null) {
        _setErrorFlag(error);
        server.flush(PMGR_FLUSH_TIMEOUT);
        // TODO: Sleep immediately? But what if called from the global exception handler?
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
     * Print the last saved error (if any) and go to sleep
     *
     * @param {table | null} lastError - Last saved error with timestamp and description
     */
    function _printLastErrorAndSleep(lastError) {
        // Timeout of checking for updates, in seconds
        const PM_CHECK_UPDATES_TIMEOUT = 5;

        // TODO: Improve logging!
        if (lastError && "ts" in lastError && "desc" in lastError) {
            _info(format("Last error (at %d): \"%s\"", lastError.ts, lastError.desc));
        }

        // After the timeout, sleep until the next update (code deploy) check
        _sleep(PMGR_CHECK_UPDATES_PERIOD, PM_CHECK_UPDATES_TIMEOUT);
    }

    /**
     * Go to sleep once Squirrel VM is idle
     *
     * @param {float} sleepTime - The deep sleep duration in seconds
     * @param {float} [delay] - Delay before sleep, in seconds
     */
    function _sleep(sleepTime, delay = 0) {
        local sleep = function() {
            _info("Going to sleep for " + sleepTime + " seconds");
            server.sleepfor(sleepTime);
        }.bindenv(this);

        imp.wakeup(delay, @() imp.onidle(sleep));
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
     * TODO: Update comment
     * Create and return the initial user configuration data
     *
     * @return {table} The initial user configuration data
     */
    function _initialData(shipped) {
        return {
            "errorFlag": false,
            "lastError": null,
            "shipped": shipped,
            "deploymentID": __EI.DEPLOYMENT_ID
        };
    }

    // TODO: Comment
    function _getOrInitializeData() {
        try {
            local userConf = _readUserConf();

            if (userConf == null) {
                _storeData(_initialData(false));
                return _initialData(false);
            }

            local fields = ["errorFlag", "lastError", "shipped", "deploymentID"];
            local data = userConf[PMGR_USER_CONFIG_FIELD];

            foreach (field in fields) {
                // This will throw an exception if no such field found
                data[field];
            }

            return data;
        } catch (err) {
            _error("Error during parsing user configuration: " + err);
        }

        _storeData(_initialData(true));
        return _initialData(true);
    }

    // TODO: Comment
    function _storeData(data) {
        local userConf = {};

        try {
            userConf = _readUserConf() || {};
        } catch (err) {
            _error("Error during parsing user configuration: " + err);
            _debug("Creating user configuration from scratch..");
        }

        userConf[PMGR_USER_CONFIG_FIELD] <- data;

        local dataStr = JSONEncoder.encode(userConf);
        _debug("Storing new user configuration: " + dataStr);

        try {
            imp.setuserconfiguration(dataStr);
        } catch (err) {
            _error(err);
        }
    }

    /**
     * Set the error flag which will restrict running the main application on the next boot
     *
     * @param {string} error - The error description
     */
    function _setErrorFlag(error) {
        local data = _getOrInitializeData();

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

        _storeData(data);
    }

    /**
     * TODO: Update comment
     * Read the user configuration
     *
     * @return {table | null} The user configuration converted from JSON to a Squirrel table
     *      or null if there was no user configuration saved
     */
    function _readUserConf() {
        local config = imp.getuserconfiguration();

        if (config == null) {
            _debug("User configuration is empty");
            return null;
        }

        config = config.tostring();
        // TODO: What if a non-readable string was written? It will be printed "binary: ..."
        _debug("User configuration: " + config);

        config = JSONParser.parse(config);

        if (typeof config != "table") {
            throw "table expected";
        }

        return config;
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
