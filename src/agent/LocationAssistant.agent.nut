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

@set CLASS_NAME = "LocationAssistant" // Class name for logging

// Google Maps Geolocation API URL
const LA_GOOGLE_MAPS_LOCATION_URL = "https://www.googleapis.com/geolocation/v1/geolocate?key=";

// Location Assistant class:
// - obtains GNSS Assist data for u-blox
// - obtains the location by cell towers info using Google Maps Geolocation API
class LocationAssistant {
    // U-Blox Assist Now instance
    _ubloxAssistNow = null;
    // Google Maps instance
    _gmaps = null;

    /**
     * Set tokens for u-blox Assist Now and Google Geolocation API
     *
     * @param {string} [ubloxAssistToken] - U-blox Assist Now token
     * @param {string} [gmapsKey] - U-blox Assist Now token
     */
    function setTokens(ubloxAssistToken = null, gmapsKey = null) {
        ubloxAssistToken && (_ubloxAssistNow = UBloxAssistNow(ubloxAssistToken));
        gmapsKey         && (_gmaps = GoogleMaps(gmapsKey));
    }

    /**
     * Obtain GNSS Assist data for u-blox
     *
     * @return {Promise} that:
     * - resolves with u-blox assist data if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function getGnssAssistData() {
        if (!_ubloxAssistNow) {
            return Promise.reject("No u-blox Assist Now token set");
        }

        ::debug("Downloading u-blox assist data...", "@{CLASS_NAME}");

        local assistOfflineParams = {
            "gnss"   : ["gps", "glo"],
            "period" : 1,
            "days"   : 3
        };

        return Promise(function(resolve, reject) {
            local onDone = function(error, resp) {
                if (error != null) {
                    return reject(error);
                }

                local assistData = _ubloxAssistNow.getOfflineMsgByDate(resp);

                if (assistData.len() == 0) {
                    return reject("No u-blox offline assist data received");
                }

                resolve(assistData);
            }.bindenv(this);

            _ubloxAssistNow.requestOffline(assistOfflineParams, onDone.bindenv(this));
        }.bindenv(this));
    }

    /**
     * Obtain the location by cell towers and WiFi networks using Google Maps Geolocation API
     *
     * @param {table} locationData - Scanned cell towers and WiFi networks
     *
     * @return {Promise} that:
     * - resolves with the location info if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function getLocationByCellInfoAndWiFi(locationData) {
        if (!_gmaps) {
            return Promise.reject("No Google Geolocation API key set");
        }

        ::debug("Requesting location from Google Geolocation API..", "@{CLASS_NAME}");
        ::debug(http.jsonencode(locationData));

        return _gmaps.getGeolocation(locationData);
    }
}

@set CLASS_NAME = null // Reset the variable
