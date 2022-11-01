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

@set CLASS_NAME = "SimUpdater" // Class name for logging

// SIM Updater class
// Initiates SIM OTA update and holds the connection for specified time to let the SIM update
class SimUpdater {
    _enabled = false;
    _duration = null;
    _keepConnectionTimer = null;

    /**
     *  Start SIM updater
     *
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

    /**
     * Update configuration
     *
     * @param {table} cfg - Configuration. May be partial.
     *                      For details, please, see the documentation
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects if the operation failed
     */
    function updateCfg(cfg) {
        local simUpdateCfg = getValFromTable(cfg, "simUpdate");
        _enabled = getValFromTable(simUpdateCfg, "enabled", _enabled);
        _duration = getValFromTable(simUpdateCfg, "duration", _duration);

        if (simUpdateCfg) {
            _enabled ? _enable() : _disable();
        }

        return Promise.resolve(null);
    }

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
