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

#require "rocky.agent.lib.nut:3.0.1"
#require "Promise.lib.nut:4.0.0"
#require "Messenger.lib.nut:0.2.0"
#require "UBloxAssistNow.agent.lib.nut:1.0.0"

@include once "github:electricimp/GoogleMaps/GoogleMaps.agent.lib.nut@develop"
@include once "../shared/Version.shared.nut"
@include once "../shared/Constants.shared.nut"
@include once "../shared/Logger/Logger.shared.nut"
@include once "CloudClient.agent.nut"
@include once "LocationAssistant.agent.nut"
@include once "CfgValidation.agent.nut"
@include once "CfgService.agent.nut"
@include once "WebUI.agent.nut"

// Main application on Imp-Agent:
// - Forwards Data messages from Imp-Device to Cloud REST API
// - Obtains GNSS Assist data for u-blox from server and returns it to Imp-Device
// - Obtains the location by cell towers and wifi networks info using Google Maps Geolocation API
//   and returns it to Imp-Device
// - Implements REST API for the tracker configuration
//   -- Sends cfg update request to Imp-Device
//   -- Stores actual cfg received from from Imp-Device
class Application {
    // Messenger instance
    _msngr = null;
    // Configuration service instance
    _cfgService = null;
    // Location Assistant instance
    _locAssistant = null;
    // Cloud Client instance
    _cloudClient = null;
    // Web UI instance. If disabled, null
    _webUI = null;

    /**
     * Application Constructor
     */
    constructor() {
        ::info("Application Version: " + APP_VERSION);
        // Initialize library for communication with Imp-Device
        _initMsngr();
        // Initialize Location Assistant
        _initLocAssistant();

@if WEB_UI || !defined(WEB_UI)
        // Initialize configuration service with no authentication
        _initCfgService();
        // Initialize Web UI
        _initWebUI();
@else
        // Initialize configuration service using env vars as a username and password for authentication
        _initCfgService(__VARS.CFG_REST_API_USERNAME, __VARS.CFG_REST_API_PASSWORD);
        // Initialize Cloud Client instance
        _initCloudClient(__VARS.CLOUD_REST_API_URL, __VARS.CLOUD_REST_API_USERNAME, __VARS.CLOUD_REST_API_PASSWORD);
        // Since Web UI is disabled, let's take tokens from env vars
        _locAssistant.setTokens(__VARS.UBLOX_ASSIST_NOW_TOKEN, __VARS.GOOGLE_MAPS_API_KEY);
@endif
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Create and initialize Messenger instance
     */
    function _initMsngr() {
        _msngr = Messenger();
        _msngr.on(APP_RM_MSG_NAME.DATA, _onData.bindenv(this));
        _msngr.on(APP_RM_MSG_NAME.GNSS_ASSIST, _onGnssAssist.bindenv(this));
        _msngr.on(APP_RM_MSG_NAME.LOCATION_CELL_WIFI, _onLocationCellAndWiFi.bindenv(this));
    }

    /**
     * Create and initialize configuration service instance
     *
     * @param {string} [user] - Username for configuration service authorization
     * @param {string} [pass] - Password for configuration service authorization
     */
    function _initCfgService(user = null, pass = null) {
        Rocky.init();
        _cfgService = CfgService(_msngr, user, pass);
    }

    /**
     * Create and initialize Location Assistant instance
     */
    function _initLocAssistant() {
        _locAssistant = LocationAssistant();
    }

    /**
     * Create and initialize Cloud Client instance
     *
     * @param {string} url - Cloud's URL
     * @param {string} user - Username for Cloud's authorization
     * @param {string} pass - Password for Cloud's authorization
     */
    function _initCloudClient(url, user, pass) {
        _cloudClient = CloudClient(url, user, pass);
    }

    /**
     * Create and initialize Web UI
     */
    function _initWebUI() {
        local tokensSetter = _locAssistant.setTokens.bindenv(_locAssistant);
        local cloudConfigurator = _initCloudClient.bindenv(this);
        _webUI = WebUI(tokensSetter, cloudConfigurator);
    }

    /**
     * Handler for Data received from Imp-Device
     *
     * @param {table} msg - Received message payload.
     * @param {function} customAck - Custom acknowledgment function.
     */
    function _onData(msg, customAck) {
        ::debug("Data received from imp-device, msgId = " + msg.id);
        local data = http.jsonencode(msg.data);

        // If Web UI is enabled, pass there the latest data
        _webUI && _webUI.newData(msg.data);

        if (_cloudClient) {
            _cloudClient.send(data)
            .then(function(_) {
                ::info("Data has been successfully sent to the cloud: " + data);
            }.bindenv(this), function(err) {
                ::error("Cloud reported an error while receiving data: " + err);
                ::error("The data caused this error: " + data);
            }.bindenv(this));
        } else {
            ::info("No cloud configured. Data received but not sent further: " + data);
        }
    }

    /**
     * Handler for GNSS Assist request received from Imp-Device
     *
     * @param {table} msg - Received message payload.
     * @param {function} customAck - Custom acknowledgment function.
     */
    function _onGnssAssist(msg, customAck) {
        local ack = customAck();

        _locAssistant.getGnssAssistData()
        .then(function(data) {
            ::info("Assist data downloaded");
            ack(data);
        }.bindenv(this), function(err) {
            ::error("Error during downloading assist data: " + err);
            // Send `null` in reply to the request
            ack(null);
        }.bindenv(this));
    }

    /**
     * Handler for Location By Cell Info and WiFi request received from Imp-Device
     *
     * @param {table} msg - Received message payload.
     * @param {function} customAck - Custom acknowledgment function.
     */
    function _onLocationCellAndWiFi(msg, customAck) {
        local ack = customAck();

        _locAssistant.getLocationByCellInfoAndWiFi(msg.data)
        .then(function(location) {
            ::info("Location obtained using Google Geolocation API");
            ack(location);
        }.bindenv(this), function(err) {
            ::error("Error during location obtaining using Google Geolocation API: " + err);
            ack(null);
        }.bindenv(this));
    }
}

// ---------------------------- THE MAIN CODE ---------------------------- //

// Run the application
app <- Application();
