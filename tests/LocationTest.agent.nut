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

#require "Promise.lib.nut:4.0.0"
#require "Messenger.lib.nut:0.2.0"

@include once "github:electricimp/GoogleMaps/GoogleMaps.agent.lib.nut@develop"
@include once "../src/shared/Constants.shared.nut"
@include once "../src/shared/Logger/Logger.shared.nut"
@include once "../src/agent/LocationAssistant.agent.nut"

// Test for Location determination.
// Periodically tries to obtain the current location by different ways.
// Imp-Agent part - tests/uses LocationAssistant

    /**
     * Handler for GNSS Assist request received from Imp-Device
     */
    function _onGnssAssist(msg, customAck) {
        local ack = customAck();

        LocationAssistant.getGnssAssistData()
        .then(function(data) {
            ::info("GNSS Assist data downloaded");
            ack(data);
        }.bindenv(this), function(err) {
            ::error("Error during downloading GNSS Assist data: " + err);
            ack(null);
        }.bindenv(this));
    }

    /**
     * Handler for Location By Cell Info and WiFi request received from Imp-Device
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

// ---------------------------- THE MAIN CODE ---------------------------- //

Logger.setLogLevel(LGR_LOG_LEVEL.DEBUG);
::info("Location test started");

// Initialize library for communication with Imp-Device
msngr <- Messenger();
msngr.on(APP_RM_MSG_NAME.GNSS_ASSIST, _onGnssAssist.bindenv(this));
msngr.on(APP_RM_MSG_NAME.LOCATION_CELL_WIFI, _onLocationCellAndWiFi.bindenv(this));