@set CLASS_NAME = "LocationAssistant" // Class name for logging

// URL to request BG96 Assist data
const LA_BG96_ASSIST_DATA_URL = "http://xtrapath4.izatcloud.net/xtra3grc.bin";

// Google Maps Geolocation API URL
const LA_GOOGLE_MAPS_LOCATION_URL = "https://www.googleapis.com/geolocation/v1/geolocate?key=";

// Location Assistant class:
// - obtains GNSS Assist data for u-blox/BG96
// - obtains the location by cell towers info using Google Maps Geolocation API
class LocationAssistant {

    /**
     * Obtains GNSS Assist data for u-blox/BG96
     *
     * @return {Promise} that:
     * - resolves with BG96 Assist data if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function getGnssAssistData() {
@if BG96_GNSS
        ::debug("Downloading BG96 assist data...", "@{CLASS_NAME}");
        // Set up an HTTP request to get the assist data
        local request = http.get(LA_BG96_ASSIST_DATA_URL);

        return Promise(function(resolve, reject) {
            request.sendasync(function(response) {
                if (response.statuscode == 200) {
                    local data = blob(response.body.len());
                    data.writestring(response.body);
                    resolve(data);
                } else {
                    reject("Unexpected response status code: " + response.statuscode);
                }
            }.bindenv(this));
        }.bindenv(this));
@else
        ::debug("Downloading u-blox assist data...", "@{CLASS_NAME}");

        local ubxAssist = UBloxAssistNow(__VARS.UBLOX_ASSIST_NOW_TOKEN);
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

                local assistData = _ubxAssist.getOfflineMsgByDate(resp);

                if (assistData.len() == 0) {
                    return reject("No u-blox offline assist data received");
                }

                resolve(assistData);
            }.bindenv(this);

            ubxAssist.requestOffline(assistOfflineParams, onDone.bindenv(this));
        }.bindenv(this));
@endif
    }

    /**
     * Obtains the location by cell towers info using Google Maps Geolocation API
     *
     * @param {Table} cellInfo - table with cell towers info
     *
     * @return {Promise} that:
     * - resolves with the location info if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function getLocationByCellInfo(cellInfo) {
        ::debug("Requesting location from Google Geolocation API. Cell towers passed: " + cellInfo.cellTowers.len(), "@{CLASS_NAME}");

        local apiKey = format("%s", __VARS.GOOGLE_MAPS_API_KEY);
        local gmapsLib = GoogleMaps(apiKey);
        return Promise(function(resolve, reject) {
            local geolocationData = null;
            geolocationData = {
                "considerIp" : "false",
                "radioType"  : cellInfo.radioType,
                "cellTowers" : cellInfo.cellTowers
            };
            gmapsLib && gmapsLib.getGeolocation(geolocationData, function(error, resp) {
                if (error) {
                    reject("Get location error: " + error);
                } else {
                    resolve({
                        "accuracy" : resp.accuracy,
                        "lat"      : resp.location.lat,
                        "lon"      : resp.location.lng,
                        "time"     : time()
                    });
                }
            });
        }.bindenv(this));
    }

    /**
     * Obtains the location by WiFi networks info using Google Maps Geolocation API
     *
     * @param {Array} wifiInfo - Array of table with WiFi networks info
     *
     * @return {Promise} that:
     * - resolves with the location info if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function getLocationByWiFiInfo(wifiInfo) {
        ::debug("Requesting location from Google Geolocation API.", "@{CLASS_NAME}");
        local apiKey = format("%s", __VARS.GOOGLE_MAPS_API_KEY);
        local gmapsLib = GoogleMaps(apiKey);
        return Promise(function(resolve, reject) {
            local geolocationData = {
                "wifiAccessPoints" : wifiInfo
            };
            gmapsLib && gmapsLib.getGeolocation(geolocationData, function(error, resp) {
                if (error) {
                    reject("Get location error: " + error);
                } else {
                    resolve({
                        "accuracy" : resp.accuracy,
                        "lat"      : resp.location.lat,
                        "lon"      : resp.location.lng,
                        "time"     : time()
                    });
                }
            });
        }.bindenv(this));
    }
}

@set CLASS_NAME = null // Reset the variable
