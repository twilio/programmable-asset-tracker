@set CLASS_NAME = "CloudClient" // Class name for logging

// Communicates with the cloud.
//   - Sends data to the cloud using REST API
//   - Basic HTTP authentication is used
//   - No buffering, data is sent immediately

// Cloud REST API URL
const CLOUD_REST_API_URL = "@{CLOUD_REST_API_URL}";

// Username to access the cloud REST API
const CLOUD_REST_API_USERNAME = "@{CLOUD_REST_API_USERNAME}";

// Password to access the cloud REST API
const CLOUD_REST_API_PASSWORD = "@{CLOUD_REST_API_PASSWORD}";

// Timeout for waiting for a response from the cloud, in seconds
// TODO - decide do we need it, how it correlates with RM ack timeout
const CLOUD_REST_API_TIMEOUT = 60;

// "Data is accepted" status code returned from the cloud
const CLOUD_REST_API_SUCCESS_CODE = 200;

class CloudClient {

    /**
    * Sends a message to the cloud
    *
    * @param {Table} data - Table with data to send to the cloud
    *
    * @return {Promise} that:
    * - resolves if the cloud accepted the data
    * - rejects with an error if the operation failed
    */
    function send(data) {
        local json = http.jsonencode(data);

        local hdr = {
            "Content-Type" : "Application/JSON",
            "Content-Length" : json.len(),
            "Authorization" : "Basic " + http.base64encode(CLOUD_REST_API_USERNAME + ":" + CLOUD_REST_API_PASSWORD)
        }
        local req = http.post(CLOUD_REST_API_URL, hdr, json);

        return Promise(function(resolve, reject) {
            req.sendasync(function(resp) {
                if (resp.statuscode == CLOUD_REST_API_SUCCESS_CODE) {
                    resolve();
                } else {
                    reject(resp.statuscode);
                }
            }.bindenv(this),
            null,
            CLOUD_REST_API_TIMEOUT)
        }.bindenv(this));
    }
}

@set CLASS_NAME = null // Reset the variable
