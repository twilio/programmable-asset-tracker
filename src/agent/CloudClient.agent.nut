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

@set CLASS_NAME = "CloudClient" // Class name for logging

// "Data is accepted" status code returned from the cloud
const CLOUD_REST_API_SUCCESS_CODE = 200;

// API endpoints
const CLOUD_REST_API_DATA_ENDPOINT = "/data";

// Communicates with the cloud.
//   - Sends data to the cloud using REST API
//   - Basic HTTP authentication is used
//   - No buffering, data is sent immediately and only once
class CloudClient {
    // Cloud's URL
    _url = null;
    // Username for Basic auth
    _user = null;
    // Password for Basic auth
    _pass = null;

    /**
     * Constructor for Cloud Client Class
     *
     * @param {string} url - Cloud's URL
     * @param {string} user - Username for Basic auth
     * @param {string} pass - Password  for Basic auth
     */
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
            }.bindenv(this));
        }.bindenv(this));
    }
}

@set CLASS_NAME = null // Reset the variable
