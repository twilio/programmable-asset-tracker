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

    // TODO: Comment
    function setTokens(ubloxAssistToken = null, gmapsKey = null) {
        ubloxAssistToken && (_ubloxAssistNow = UBloxAssistNow(ubloxAssistToken));
        gmapsKey         && (_gmaps = GoogleMaps(gmapsKey));
    }

    /**
     * Obtains GNSS Assist data for u-blox
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
     * Obtains the location by cell towers and WiFi networks using Google Maps Geolocation API
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
