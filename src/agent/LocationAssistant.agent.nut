@set CLASS_NAME = "LocationAssistant" // Class name for logging

// URL to request BG96 Assist data
const LA_BG96_ASSIST_DATA_URL = "http://xtrapath4.izatcloud.net/xtra3grc.bin";

// Google Maps Geolocation API URL
const LA_GOOGLE_MAPS_LOCATION_URL = "https://www.googleapis.com/geolocation/v1/geolocate?key=";

// Location Assistant class:
// - obtains GNSS Assist data for BG96
// - obtains the location by cell towers info using Google Maps Geolocation API
class LocationAssistant {

    /**
     * Obtains GNSS Assist data for BG96
     *
     * @return {Promise} that:
     * - resolves with BG96 Assist data if the operation succeeded
     * - rejects with an error if the operation failed
     */
    function getGnssAssistData() {
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

        // Set up an HTTP request to get the location
        local url = format("%s%s", LA_GOOGLE_MAPS_LOCATION_URL, __VARS.GOOGLE_MAPS_API_KEY);
        local headers = { "Content-Type" : "application/json" };
        local body = {
            "considerIp" : "false",
            "radioType"  : cellInfo.radioType,
            "cellTowers" : cellInfo.cellTowers
        };

        local request = http.post(url, headers, http.jsonencode(body));

        return Promise(function(resolve, reject) {
            request.sendasync(function(resp) {
                if (resp.statuscode == 200) {
                    try {
                        local parsed = http.jsondecode(resp.body);
                        resolve({
                            "accuracy" : parsed.accuracy,
                            "lat"      : parsed.location.lat,
                            "lon"      : parsed.location.lng,
                            "time"     : time()
                        });
                    } catch(e) {
                        reject("Response parsing error: " + e);
                    }
                } else {
                    reject("Unexpected response status code: " + resp.statuscode);
                }
            }.bindenv(this))
        }.bindenv(this));
    }
}

@set CLASS_NAME = null // Reset the variable
