#require "rocky.class.nut:2.0.2"
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

// Main application on Imp-Agent:
// - Forwards Data messages from Imp-Device to Cloud REST API
// - Obtains GNSS Assist data for BG96 from server and returns it to Imp-Device
// - Obtains the location by cell towers and wifi networks info using Google Maps Geolocation API
//   and returns it to Imp-Device
// - Implements REST API for the tracker configuration
//   -- Sends cfg update request to Imp-Device
//   -- Stores actual cfg received from from Imp-Device

class Application {
    // Messenger instance
    _msngr = null;
    // Rocky instance
    _rocky = null;
    // Configuration service instance
    _cfgService =null;

    /**
     * Application Constructor
     */
    constructor() {
        ::info("Application Version: " + APP_VERSION);
        // Initialize logger settings
        _initLoggerSettings();
        // Initialize library for communication with Imp-Device
        _initMsngr();
        // Initialize configuration service
        _initCfgService();
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Initialize Logger by settings from Imp-agent persistent memory
     */
    function _initLoggerSettings() {
        local storedAgentData = server.load();
        if (!("deploymentId" in storedAgentData)) {
            ::debug("No saved deployment ID found");
        } else if (storedAgentData["deploymentId"] == __EI.DEPLOYMENT_ID) {
            local logLevel = "agentLogLevel" in storedAgentData ? 
                             storedAgentData["agentLogLevel"] : 
                             null;
            if (logLevel) {
                ::info("Imp-agent log level is set to \"" + logLevel + "\"");
                Logger.setLogLevelStr(logLevel);
            } else {
                ::debug("No saved imp-agent log level found");
            }
        } else {
            ::debug("Current Deployment Id: " + 
                    __EI.DEPLOYMENT_ID + 
                    " - is not equal to the stored one");
        }
    }

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
     */
    function _initCfgService() {
        _rocky = Rocky();
        _cfgService = CfgService(_msngr, _rocky);
    }

    /**
     * Handler for Data received from Imp-Device
     *
     * @param {table} msg - Received message payload.
     * @param customAck - Custom acknowledgment function.
     */
    function _onData(msg, customAck) {
        ::debug("Data received from imp-device, msgId = " + msg.id);
        local data = http.jsonencode(msg.data);

        CloudClient.send(data)
        .then(function(_) {
            ::info("Data has been successfully sent to the cloud: " + data);
        }.bindenv(this), function(err) {
            ::error("Cloud reported an error while receiving data: " + err);
            ::error("The data caused this error: " + data);
        }.bindenv(this));
    }

    /**
     * Handler for GNSS Assist request received from Imp-Device
     *
     * @param {table} msg - Received message payload.
     * @param customAck - Custom acknowledgment function.
     */
    function _onGnssAssist(msg, customAck) {
        local ack = customAck();

        LocationAssistant.getGnssAssistData()
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
     * @param customAck - Custom acknowledgment function.
     */
    function _onLocationCellAndWiFi(msg, customAck) {
        local ack = customAck();

        LocationAssistant.getLocationByCellInfoAndWiFi(msg.data)
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
