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

@set CLASS_NAME = "CfgManager" // Class name for logging

// File names used by Cfg Manager
enum CFGM_FILE_NAMES {
    CFG = "cfg"
}

// Configuration Manager class:
// - Passes the configuration (default or custom) to start modules
// - Receives configuration updates from the agent
// - Finds a diff between the current and the new configurations
// - Passes the diff to the modules
// - Stores the latest configuration version
// - Reports the latest configuration version to the agent
class CfgManager {
    // Array of modules to be configured
    _modules = null;
    // SPIFlashFileSystem storage for configuration
    _storage = null;
    // Promise or null
    _processingCfg = null;
    // The actual (already applied) configuration
    _actualCfg = null;

    /**
     * Constructor for Configuration Manager class
     *
     * @param {array} modules - Application modules (must have start() and updateCfg() methods)
     */
    constructor(modules) {
        _modules = modules;

        // Create storage
        _storage = SPIFlashFileSystem(HW_CFGM_SFFS_START_ADDR, HW_CFGM_SFFS_END_ADDR);
        _storage.init();
    }

    /**
     * Load saved configuration or the default one and start modules, report the configuration
     */
    function start() {
        // Let's keep the connection to be able to report the configuration once it is deployed
        cm.keepConnection("@{CLASS_NAME}", true);

        rm.on(APP_RM_MSG_NAME.CFG, _onCfgUpdate.bindenv(this));

        local defaultCfgUsed = false;
        local cfg = _loadCfg() || (defaultCfgUsed = true) && _defaultCfg();
        local promises = [];

        try {
            ::info(format("Deploying the %s configuration with updateId: %s",
                          defaultCfgUsed ? "default" : "saved", cfg.updateId), "@{CLASS_NAME}");

            _applyDebugSettings(cfg);

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
                // This will reboot the imp. This call doesn't return!
                _reboot();
            }
        }.bindenv(this))
        .finally(function(_) {
            cm.keepConnection("@{CLASS_NAME}", false);
            _processingCfg = null;
        }.bindenv(this));
    }

    function _onCfgUpdate(msg, customAck) {
        // Let's keep the connection to be able to report the configuration once it is deployed
        cm.keepConnection("@{CLASS_NAME}", true);

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

            _diff(cfgUpdate, _actualCfg);
            _applyDebugSettings(cfgUpdate);

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
            cm.keepConnection("@{CLASS_NAME}", false);
            _processingCfg = null;
        }.bindenv(this));
    }

    function _applyDebugSettings(cfg) {
        if (!("debug" in cfg)) {
            return;
        }

        local debugSettings = cfg.debug;

        ::debug("Applying debug settings..", "@{CLASS_NAME}");

        if ("logLevel" in debugSettings) {
            ::info("Setting log level: " + debugSettings.logLevel, "@{CLASS_NAME}");
            Logger.setLogLevelStr(debugSettings.logLevel);
        }
    }

    function _reportCfg() {
        ::debug("Reporting cfg..", "@{CLASS_NAME}");

        local cfgReport = {
            "configuration": tableFullCopy(_actualCfg)
            "description": {
                "cfgTimestamp": time()
            }
        };

        rm.send(APP_RM_MSG_NAME.CFG, cfgReport, RM_IMPORTANCE_HIGH);
    }

    function _reboot() {
        const CFGM_FLUSH_TIMEOUT = 5;

        server.flush(CFGM_FLUSH_TIMEOUT);
        server.restart();
    }

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

    function _defaultCfg() {
        local cfg =
        @include "DefaultConfiguration.device.nut"
        return cfg;
    }

    // -------------------- STORAGE METHODS -------------------- //

    function _saveCfg(cfg = null, fileName = CFGM_FILE_NAMES.CFG) {
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

    function _loadCfg(fileName = CFGM_FILE_NAMES.CFG) {
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

    function _eraseCfg(fileName = CFGM_FILE_NAMES.CFG) {
        try {
            // Erase the existing file if any
            _storage.fileExists(fileName) && _storage.eraseFile(fileName);
        } catch (err) {
            ::error(format("Couldn't erase cfg (file name = %s): %s", fileName, err), "@{CLASS_NAME}");
        }
    }
}

@set CLASS_NAME = null // Reset the variable
