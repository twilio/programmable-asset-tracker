#require "Promise.lib.nut:4.0.0"
#require "Messenger.lib.nut:0.2.0"

@include once "../shared/Version.shared.nut"
@include once "../shared/Constants.shared.nut"
@include once "../shared/Logger.shared.nut"
//@include once "CloudClient.agent.nut"
@include once "LocationAssistant.agent.nut"

// Main application on Imp-Agent:
// - Forwards Data messages from Imp-Device to Cloud REST API
// - Obtains GNSS Assist data for BG96 from server and returns it to Imp-Device
// - Obtains the location by cell towers info using Google Maps Geolocation API
//   and returns it to Imp-Device

class Application {
    // Messenger instance
    _msngr = null;

    /**
     * Application Constructor
     */
    constructor() {
        ::info("Application Version: " + APP_VERSION);

        // Initialize library for communication with Imp-Device
        _initMsngr();
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Create and initialize Messenger instance
     */
    function _initMsngr() {
        _msngr = Messenger();
        _msngr.on(APP_RM_MSG_NAME.DATA, _onData.bindenv(this));
        _msngr.on(APP_RM_MSG_NAME.GNSS_ASSIST, _onGnssAssist.bindenv(this));
        _msngr.on(APP_RM_MSG_NAME.LOCATION_CELL, _onLocationCell.bindenv(this));
    }

    /**
     * Handler for Data received from Imp-Device
     */
    function _onData(msg, customAck) {
        ::debug("Data received");

        local ack = customAck();

        // Send data to Cloud REST API - TODO

    }

    /**
     * Handler for GNSS Assist request received from Imp-Device
     */
    function _onGnssAssist(msg, customAck) {
        local ack = customAck();

        LocationAssistant.getGnssAssistData()
        .then(function(data) {
            ::info("BG96 Assist data downloaded");
            ack(data);
        }.bindenv(this), function(err) {
            ::error("Error during downloading BG96 Assist data: " + err);
            ack(null);
        }.bindenv(this));
    }

    /**
     * Handler for Location By Cell Info request received from Imp-Device
     */
    function _onLocationCell(msg, customAck) {
        local ack = customAck();

        LocationAssistant.getLocationByCellInfo(msg.data)
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

// Set default log level
Logger.setLogLevel(LGR_LOG_LEVEL.@{DEFAULT_LOG_LEVEL ? DEFAULT_LOG_LEVEL : "INFO"});

// Run the application
app <- Application();
