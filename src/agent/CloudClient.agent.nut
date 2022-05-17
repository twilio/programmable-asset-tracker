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
    // TODO: Comment
    _url = null;
    // TODO: Comment
    _user = null;
    // TODO: Comment
    _pass = null;

    // TODO: Comment
    constructor(url, user, pass) {
        _url = url;
        _user = user;
        _pass = pass;
    }

    /**
    * Sends a message to the cloud
    *
    * @param {string} body - Data to send to the cloud
    *
    * @return {Promise} that:
    * - resolves if the cloud accepted the data
    * - rejects with an error if the operation failed
    */
    function send(body) {
        local headers = {
            "Content-Type" : "application/json",
            "Content-Length" : body.len(),
            "Authorization" : "Basic " + http.base64encode(_user + ":" + _pass)
        };
        local req = http.post(_url + CLOUD_REST_API_DATA_ENDPOINT, headers, body);

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
