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
