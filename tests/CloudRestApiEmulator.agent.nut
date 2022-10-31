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

#require "rocky.class.nut:2.0.2"

// Username to access the cloud REST API
const CLOUD_REST_API_USERNAME = "test";
// Password to access the cloud REST API
const CLOUD_REST_API_PASSWORD = "test";
// API endpoints:
const CLOUD_REST_API_DATA_ENDPOINT = "/data";

expectedAuthHeader <- "Basic " + http.base64encode(CLOUD_REST_API_USERNAME + ":" + CLOUD_REST_API_PASSWORD);

rocky <- Rocky();

rocky.authorize(function(context) {
    return context.getHeader("Authorization") == expectedAuthHeader.tostring();
});

rocky.onUnauthorized(function(context) {
    server.error("Unauthorized request!");
    context.send(401, { "message": "Unauthorized" });
});

function postDataRockyHandler(context) {
    server.log("Inbound request: POST data");

    local body = context.req.body;

    if (typeof body != "table") {
        server.log("Invalid request");
        return context.send(400);
    }

    server.log("Request body: " + http.jsonencode(body));
    context.send(200);
}

rocky.post(CLOUD_REST_API_DATA_ENDPOINT, postDataRockyHandler);

server.log("Emulator started");
