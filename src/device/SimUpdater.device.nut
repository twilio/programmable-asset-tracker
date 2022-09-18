@set CLASS_NAME = "SimUpdater" // Class name for logging

// TODO: Comment
class SimUpdater {
    _enabled = false;
    _duration = null;
    _keepConnectionTimer = null;

    /**
     *  Start SIM updater.
     *  @param {table} cfg - Table with the full configuration.
     *                       For details, please, see the documentation
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function start(cfg) {
        updateCfg(cfg);

        return Promise.resolve(null);
    }

    // TODO: Comment
    function updateCfg(cfg) {
        local simUpdateCfg = getValFromTable(cfg, "simUpdate");
        _enabled = getValFromTable(simUpdateCfg, "enabled", _enabled);
        _duration = getValFromTable(simUpdateCfg, "duration", _duration);

        if (simUpdateCfg) {
            _enabled ? _enable() : _disable();
        }

        return Promise.resolve(null);
    }

    // TODO: Comment
    function _enable() {
        // Maximum server flush duration (sec) before forcing SIM-OTA
        const SU_SERVER_FLUSH_TIMEOUT = 5;

        ::debug("Enabling SIM OTA updates..", "@{CLASS_NAME}");

        local onConnected = function() {
            if (_keepConnectionTimer) {
                return;
            }

            ::info("Forcing SIM OTA update..", "@{CLASS_NAME}");

            // Without server.flush() call we can face very often failures in forcing SIM-OTA
            server.flush(SU_SERVER_FLUSH_TIMEOUT);

            if (BG96_Modem.forceSuperSimOTA()) {
                ::debug("SIM OTA call succeeded. Now keeping the device connected for " + _duration + " seconds", "@{CLASS_NAME}");

                cm.keepConnection("@{CLASS_NAME}", true);

                local complete = function() {
                    ::debug("Stopped keeping the device connected", "@{CLASS_NAME}");

                    _keepConnectionTimer = null;
                    cm.keepConnection("@{CLASS_NAME}", false);
                }.bindenv(this);

                _keepConnectionTimer = imp.wakeup(_duration, complete);
            } else {
                ::error("SIM OTA call failed", "@{CLASS_NAME}");
            }
        }.bindenv(this);

        cm.onConnect(onConnected, "@{CLASS_NAME}");
        cm.isConnected() && onConnected();
    }

    // TODO: Comment
    function _disable() {
        if (_keepConnectionTimer) {
            imp.cancelwakeup(_keepConnectionTimer);
            _keepConnectionTimer = null;
        }

        cm.onConnect(null, "@{CLASS_NAME}");
        cm.keepConnection("@{CLASS_NAME}", false);

        ::debug("SIM OTA updates disabled", "@{CLASS_NAME}");
    }
}

@set CLASS_NAME = null // Reset the variable
