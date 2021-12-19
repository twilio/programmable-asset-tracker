@set CLASS_NAME = "CloudClient" // Class name for logging

// Communicates with the cloud.
//   - Sends data to the cloud using REST API
//   - Basic HTTP authentication is used
//   - No buffering, data is sent immediately

// Timeout for waiting for a response from the cloud, in seconds
// TODO - decide do we need it, how it correlates with RM ack timeout
const CLOUD_REST_API_TIMEOUT = 60;

// "Data is accepted" status code returned from the cloud
const CLOUD_REST_API_SUCCESS_CODE = 200;

// API endpoints
const CLOUD_REST_API_DATA_ENDPOINT = "/data";

class CloudClient {

    /**
    * Sends a message to the cloud
    *
    * @param {string} data - Data to send to the cloud
    *
    * @return {Promise} that:
    * - resolves if the cloud accepted the data
    * - rejects with an error if the operation failed
    */
    function send(data) {
        local headers = {
            "Content-Type" : "application/json",
            "Content-Length" : data.len(),
            "Authorization" : "Basic " + http.base64encode(__VARS.CLOUD_REST_API_USERNAME + ":" + __VARS.CLOUD_REST_API_PASSWORD)
        };
        local req = http.post(__VARS.CLOUD_REST_API_URL + CLOUD_REST_API_DATA_ENDPOINT, headers, body);

        return Promise(function(resolve, reject) {
            req.sendasync(function(resp) {
                if (resp.statuscode == CLOUD_REST_API_SUCCESS_CODE) {
                    resolve();
                } else {
                    reject(resp.statuscode);
                }
            }.bindenv(this),
            null,
            CLOUD_REST_API_TIMEOUT);
        }.bindenv(this));
    }
}

@set CLASS_NAME = null // Reset the variable
