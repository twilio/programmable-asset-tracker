@include once "../src/shared/Logger.shared.nut"

// Emulator of the cloud REST API:
//   - receives, verifies and prints out data

// Username to access the cloud REST API
const CLOUD_REST_API_USERNAME = "@{CLOUD_REST_API_USERNAME}";
// Password to access the cloud REST API
const CLOUD_REST_API_PASSWORD = "@{CLOUD_REST_API_PASSWORD}";

function onRequest(req, resp) {
    ::info("Received post request:")
    local authorization = split(req.headers.authorization, " ");
    if (authorization.len() != 2) {
        ::error("Unauthorized: Authorization header format error.");
        resp.send(401, "Unauthorized: Authorization header format error.");
        return;
    }
    if (authorization[0].tolower() != "basic") {
        ::error("Unauthorized: \"" + authorization[0] + "\"" + " authorization type is not supported.");
        resp.send(401, "Unauthorized: \"" + authorization[0] + "\"" + " authorization type is not supported.");
        return;
    }

    local userData = split(http.base64decode(authorization[1]).tostring(), ":");
    if ((userData.len() != 2)
        || (userData[0] != CLOUD_REST_API_USERNAME)
        || (userData[1] != CLOUD_REST_API_PASSWORD)
    ) {
        ::error("Unauthorized: HTTP USERNAME/PASSWORD is not valid.");
        resp.send(401, "Unauthorized: HTTP USERNAME/PASSWORD is not valid.");
        return;
    }

    if (req.path != "/data") {
        ::error("Endpoint \"" + req.path + "\" is not supported.");
        resp.send(404, "Endpoint \"" + req.path + "\" is not supported.");
        return;
    }

    if (req.method != "POST") {
        ::error("Method \"" + request.method + "\" is not supported.");
        resp.send(404, "Method \"" + request.method + "\" is not supported.");
        return;
    }

    if (!req.body.len()) {
        ::error("Request received without data");
        resp.send(400, "Request received without data");
        return;
    }

    try {
        local data = http.jsondecode(req.body.tolower());
        ::info("Received the following data:");
        ::info(data);
        resp.send(200, "OK");
        return;
    } catch(exp) {
        ::error("Bad request - JSON can not be decoded: " + exp);
        resp.send(400, "Bad request - JSON can not be decoded: " + exp);
        return;
    }

}

// Setting a request handler
http.onrequest(onRequest);
