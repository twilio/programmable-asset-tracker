@set CLASS_NAME = "CfgManager" // Class name for logging

// TODO: Replace with an enum?
// TODO: Comment
const CFGM_CFG_FILE_NAME = "cfg";
// TODO: Comment
const CFGM_DEBUG_FILE_NAME = "debug";


// TODO: Comment
class CfgManager {
    // Array of modules to be configured
    _modules = null;
    // SPIFlashFileSystem storage for configuration
    _storage = null;
    // Promise or null
    _processingCfg = null;
    // TODO: Comment
    _actualCfg = null;
    // TODO: Comment
    _actualDebugCfg = null;

    // TODO: Comment
    constructor(modules) {
        _modules = modules;

        // Create storage
        _storage = SPIFlashFileSystem(HW_CFGM_SFFS_START_ADDR, HW_CFGM_SFFS_END_ADDR);
        _storage.init();
    }

    // TODO: Comment
    function start() {
        // TODO: Hold the connection?

        rm.on(APP_RM_MSG_NAME.CFG, _onCfgUpdate.bindenv(this));

        // Erase the debug cfg if a new deployment detected
        pm.isNewDeployment() && _eraseCfg(CFGM_DEBUG_FILE_NAME);
        // Apply the debug settings (if any)
        _actualDebugCfg = _loadCfg(CFGM_DEBUG_FILE_NAME) || {};
        _applyDebugCfg(_actualDebugCfg);

        local defaultCfgUsed = false;
        local cfg = _loadCfg() || (defaultCfgUsed = true) && _defaultCfg();
        local promises = [];

        try {
            ::info(format("Deploying the %s configuration with updateId: %s",
                          defaultCfgUsed ? "default" : "saved", cfg.updateId), "@{CLASS_NAME}");

            foreach (module in _modules) {
                promises.push(module.start(cfg));
            }
        } catch (err) {
            promises.push(Promise.reject(err));
        }

        _processingCfg = Promise.all(promises)
        .then(function(_) {
            ::info("The configuration has been successfully deployed", "@{CLASS_NAME}");
            _actualCfg = cfg;

            // Send the actual cfg to the agent
            _reportCfg();
        }.bindenv(this), function(err) {
            ::error("Couldn't deploy the configuration: " + err, "@{CLASS_NAME}");

            if (defaultCfgUsed) {
                // This will raise the error flag and reboot the imp. This call doesn't return!
                pm.enterEmergencyMode();
            } else {
                ::debug(cfg, "@{CLASS_NAME}");

                // Erase both the main cfg and the debug one
                _eraseCfg();
                _eraseCfg(CFGM_DEBUG_FILE_NAME);
                // This will reboot the imp. This call doesn't return!
                _reboot();
            }
        }.bindenv(this))
        .finally(function(_) {
            _processingCfg = null;
        }.bindenv(this));
    }

    // TODO: Comment
    function _onCfgUpdate(msg, customAck) {
        // TODO: Hold the connection?

        // Cfg update may contain "debug" field at the top level.
        // This field contains settings for debug features and is handled separately from the rest of the cfg update

        local cfgUpdate = msg.data;
        local updateId = cfgUpdate.updateId;

        ::info("Configuration update received: " + updateId, "@{CLASS_NAME}");

        _processingCfg = (_processingCfg || Promise.resolve(null))
        .then(function(_) {
            ::debug("Starting processing " + updateId + " cfg update..", "@{CLASS_NAME}");

            if (updateId == _actualCfg.updateId) {
                ::info("Configuration update has the same updateId as the actual cfg", "@{CLASS_NAME}");
                // Resolve with null to indicate that the update hasn't been deployed due to no sense
                return Promise.resolve(null);
            }

            // Apply the debug settings (if any) and remove them from the data received
            ("debug" in cfgUpdate) && _onDebugCfgUpdate(delete cfgUpdate.debug);

            _diff(cfgUpdate, _actualCfg);

            local promises = [];

            foreach (module in _modules) {
                promises.push(module.updateCfg(cfgUpdate));
            }

            return Promise.all(promises);
        }.bindenv(this))
        .then(function(result) {
            if (result == null) {
                // No cfg deploy has been done
                return;
            }

            ::info("The configuration update has been successfully deployed", "@{CLASS_NAME}");

            // Apply the update (diff) to the actual cfg
            _applyDiff(cfgUpdate, _actualCfg);
            // Save the actual cfg in the storage
            _saveCfg();
            // Send the actual cfg to the agent
            _reportCfg();
        }.bindenv(this), function(err) {
            ::error("Couldn't deploy the configuration update: " + err, "@{CLASS_NAME}");
            _reboot();
        }.bindenv(this))
        .finally(function(_) {
            _processingCfg = null;
        }.bindenv(this));
    }

    // TODO: Comment
    function _onDebugCfgUpdate(debugCfgUpdate) {
        ::info("Debug cfg update received", "@{CLASS_NAME}");

        _diff(debugCfgUpdate, _actualDebugCfg);

        if (debugCfgUpdate.len() == 0) {
            ::debug("The debug cfg update has no changes to the actual debug cfg", "@{CLASS_NAME}");
            return;
        }

        _applyDebugCfg(debugCfgUpdate);
        _applyDiff(debugCfgUpdate, _actualDebugCfg);
        _saveCfg(_actualDebugCfg, CFGM_DEBUG_FILE_NAME);
    }

    // TODO: Comment
    function _applyDebugCfg(debugCfg) {
        ::debug("Applying the debug cfg..", "@{CLASS_NAME}");

        if (debugCfg && "logLevel" in debugCfg) {
            ::info("Setting log level: " + debugCfg.logLevel, "@{CLASS_NAME}");
            Logger.setLogLevelStr(debugCfg.logLevel);
        }
    }

    // TODO: Comment
    function _reportCfg() {
        ::debug("Reporting cfg..", "@{CLASS_NAME}");

        local cfgReport = {
            "configuration": _tableFullCopy(_actualCfg)
            "description": {
                "cfgTimestamp": time()
            }
        };

        cfgReport.configuration.debug <- _tableFullCopy(_actualDebugCfg);
        rm.send(APP_RM_MSG_NAME.CFG, cfgReport, RM_IMPORTANCE_HIGH);
    }

    // TODO: Comment
    function _tableFullCopy(tbl) {
        // TODO: This is a quick workaround. May need to be improved!
        return Serializer.deserialize(Serializer.serialize(tbl));
    }

    // TODO: Comment
    function _reboot() {
        const CFGM_FLUSH_TIMEOUT = 5;

        server.flush(CFGM_FLUSH_TIMEOUT);
        server.restart();
    }

    // TODO: Comment
    function _diff(cfgUpdate, actualCfg, path = "") {
        // The list of the paths which should be handled in a special way when making or applying a diff.
        // When making a diff, we just don't touch these paths (and their sub-paths) in the cfg update - leave them as is.
        // When applying a diff, we just fully replace these paths (their values) in the actual cfg with the values from the diff.
        // Every path must be prefixed with "^" and postfixed with "$". Every segment of a path must be prefixed with "/".
        // NOTE: It's assumed that "^", "/" and "$" are not used in keys of a configuration
        const CFGM_DIFF_SPECIAL_PATHS = @"^/locationTracking/bleDevices/generic$
                                          ^/locationTracking/bleDevices/iBeacon$";

        local keysToRemove = [];

        foreach (k, v in cfgUpdate) {
            // The full path which includes the key currently considered
            local fullPath = path + "/" + k;
            // Check if this path should be skipped
            if (!(k in actualCfg) || CFGM_DIFF_SPECIAL_PATHS.find("^" + fullPath + "$") != null) {
                continue;
            }

            // We assume that configuration can only contain nested tables, not arrays
            if (type(v) == "table") {
                // Make a diff from a nested table
                _diff(v, actualCfg[k], fullPath);
                // If the table is empty after making a diff, we just remove it as it doesn't make sense anymore
                (v.len() == 0) && keysToRemove.push(k);
            } else if (v == actualCfg[k]) {
                keysToRemove.push(k);
            }
        }

        foreach (k in keysToRemove) {
            delete cfgUpdate[k];
        }
    }

    // TODO: Comment
    function _applyDiff(diff, actualCfg, path = "") {
        foreach (k, v in diff) {
            // The full path which includes the key currently considered
            local fullPath = path + "/" + k;
            // Check if this path should be fully replaced in the actual cfg
            local fullyReplace = !(k in actualCfg) || CFGM_DIFF_SPECIAL_PATHS.find("^" + fullPath + "$") != null;

            // We assume that configuration can only contain nested tables, not arrays
            if (type(v) == "table" && !fullyReplace) {
                // Make a diff from a nested table
                _applyDiff(v, actualCfg[k], fullPath);
            } else {
                actualCfg[k] <- v;
            }
        }
    }

    // TODO: Comment
    function _defaultCfg() {
        local cfg =
        @include "DefaultConfiguration.device.nut"
        return cfg;
    }

    // -------------------- STORAGE METHODS -------------------- //

    // TODO: Comment
    function _saveCfg(cfg = null, fileName = CFGM_CFG_FILE_NAME) {
        ::debug("Saving cfg (fileName = " + fileName + ")..", "@{CLASS_NAME}");

        cfg = cfg || _actualCfg;

        _eraseCfg(fileName);

        try {
            local file = _storage.open(fileName, "w");
            file.write(Serializer.serialize(cfg));
            file.close();
        } catch (err) {
            ::error(format("Couldn't save cfg (file name = %s): %s", fileName, err), "@{CLASS_NAME}");
        }
    }

    // TODO: Comment
    function _loadCfg(fileName = CFGM_CFG_FILE_NAME) {
        try {
            if (_storage.fileExists(fileName)) {
                local file = _storage.open(fileName, "r");
                local data = file.read();
                file.close();
                return Serializer.deserialize(data);
            }
        } catch (err) {
            ::error(format("Couldn't load cfg (file name = %s): %s", fileName, err), "@{CLASS_NAME}");
        }

        return null;
    }

    // TODO: Comment
    function _eraseCfg(fileName = CFGM_CFG_FILE_NAME) {
        try {
            // Erase the existing file if any
            _storage.fileExists(fileName) && _storage.eraseFile(fileName);
        } catch (err) {
            ::error(format("Couldn't erase cfg (file name = %s): %s", fileName, err), "@{CLASS_NAME}");
        }
    }
}

@set CLASS_NAME = null // Reset the variable