// Emulator of the cloud REST API:
//   - receives, verifies and prints out data

// Username to access the cloud REST API
const CLOUD_REST_API_USERNAME = "test";
// Password to access the cloud REST API
const CLOUD_REST_API_PASSWORD = "test";

function onRequest(req, resp) {
    server.log("Received post request:")
    local authorization = split(req.headers.authorization, " ");
    if (authorization.len() != 2) {
        server.error("Unauthorized: Authorization header format error.");
        resp.send(401, "Unauthorized: Authorization header format error.");
        return;
    }
    if (authorization[0].tolower() != "basic") {
        server.error("Unauthorized: \"" + authorization[0] + "\"" + " authorization type is not supported.");
        resp.send(401, "Unauthorized: \"" + authorization[0] + "\"" + " authorization type is not supported.");
        return;
    }

    local userData = split(http.base64decode(authorization[1]).tostring(), ":");
    if ((userData.len() != 2)
        || (userData[0] != CLOUD_REST_API_USERNAME)
        || (userData[1] != CLOUD_REST_API_PASSWORD)
    ) {
        server.error("Unauthorized: HTTP USERNAME/PASSWORD is not valid.");
        resp.send(401, "Unauthorized: HTTP USERNAME/PASSWORD is not valid.");
        return;
    }

    if (req.path != "/data") {
        server.error("Endpoint \"" + req.path + "\" is not supported.");
        resp.send(404, "Endpoint \"" + req.path + "\" is not supported.");
        return;
    }

    if (req.method != "POST") {
        server.error("Method \"" + request.method + "\" is not supported.");
        resp.send(404, "Method \"" + request.method + "\" is not supported.");
        return;
    }

    if (!req.body.len()) {
        server.error("Request received without data");
        resp.send(400, "Request received without data");
        return;
    }

    server.log("Received the following data:");
    server.log(req.body);
    resp.send(200, "OK");
}

// Setting a request handler
http.onrequest(onRequest);
