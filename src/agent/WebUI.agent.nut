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

@set CLASS_NAME = "WebUI" // Class name for logging

// Index page endpoint
const WEBUI_INDEX_PAGE_ENDPOINT = "/";
// Data (latest message from the device, alerts history) API endpoint
const WEBUI_DATA_ENDPOINT = "/web-ui/data";
// Tokens (u-blox, google) setting API endpoint
const WEBUI_TOKENS_ENDPOINT = "/web-ui/tokens";
// Cloud settings (URL, user, pass) API endpoint
const WEBUI_CLOUD_SETTINGS_ENDPOINT = "/web-ui/cloud-settings";

// Maximum alerts to be kept in the history
const WEBUI_ALERTS_HISTORY_LEN = 10;

// Web UI class:
// - Provides HTTP endpoints for Web interface
// - Stores data required for Web interface
class WebUI {
    // Latest data message received from the device
    _latestData = null;
    // Alerts history
    _alertsHistory = null;
    // Tokens setter function
    _tokensSetter = null;
    // Cloud configurator function
    _cloudConfigurator = null;

    /**
     * Constructor for Web UI class
     *
     * @param {function} tokensSetter - Tokens setter function
     * @param {function} cloudConfigurator - Cloud configurator function
     */
    constructor(tokensSetter, cloudConfigurator) {
        _tokensSetter = tokensSetter;
        _cloudConfigurator = cloudConfigurator;

        Rocky.on("GET", WEBUI_INDEX_PAGE_ENDPOINT, _getIndexPageRockyHandler.bindenv(this));
        Rocky.on("GET", WEBUI_DATA_ENDPOINT, _getDataRockyHandler.bindenv(this));
        Rocky.on("PATCH", WEBUI_TOKENS_ENDPOINT, _patchTokensRockyHandler.bindenv(this));
        Rocky.on("PATCH", WEBUI_CLOUD_SETTINGS_ENDPOINT, _patchCloudSettingsRockyHandler.bindenv(this));

        _alertsHistory = [];
    }

    /**
     * Pass new data received from the device
     *
     * @param {table} data - Tokens setter function
     */
    function newData(data) {
        _latestData = data;

        foreach (alert in data.alerts) {
            _alertsHistory.insert(0, {
                "alert": alert,
                "ts": data.timestamp
            });
        }

        if (_alertsHistory.len() > WEBUI_ALERTS_HISTORY_LEN) {
            _alertsHistory.resize(WEBUI_ALERTS_HISTORY_LEN);
        }
    }

    // -------------------- PRIVATE METHODS -------------------- //

    function _getIndexPageRockyHandler(context) {
        ::debug("GET " + WEBUI_INDEX_PAGE_ENDPOINT + " request received", "@{CLASS_NAME}");

        // Return the index.html page file
        context.send(200, _indexHtml());
    }

    function _getDataRockyHandler(context) {
        ::debug("GET " + WEBUI_DATA_ENDPOINT + " request received", "@{CLASS_NAME}");

        local data = {
            "latestData": _latestData,
            "alertsHistory": _alertsHistory
        };

        // Return the data
        context.send(200, data);
    }

    function _patchTokensRockyHandler(context) {
        ::debug("PATCH " + WEBUI_TOKENS_ENDPOINT + " request received", "@{CLASS_NAME}");

        local tokens = context.req.body;
        local ubloxToken = "ublox" in tokens ? tokens.ublox : null;
        local gmapsKey   = "gmaps" in tokens ? tokens.gmaps : null;
        _tokensSetter(ubloxToken, gmapsKey);

        context.send(200);
    }

    function _patchCloudSettingsRockyHandler(context) {
        ::debug("PATCH " + WEBUI_CLOUD_SETTINGS_ENDPOINT + " request received", "@{CLASS_NAME}");

        local cloudSettings = context.req.body;
        _cloudConfigurator(cloudSettings.url, cloudSettings.user, cloudSettings.pass);

        context.send(200);
    }

    function _indexHtml() {
        return "@{include("WebUI/index.html") | escape}";
    }
}

@set CLASS_NAME = null // Reset the variable
