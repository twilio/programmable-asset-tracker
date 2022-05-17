@set CLASS_NAME = "WebUI" // Class name for logging

// Configuration API endpoint
const WEBUI_INDEX_PAGE_ENDPOINT = "/";
// TODO: Comment
const WEBUI_DATA_ENDPOINT = "/web-ui/data";
// TODO: Comment
const WEBUI_TOKENS_ENDPOINT = "/web-ui/tokens";
// TODO: Comment
const WEBUI_CLOUD_SETTINGS_ENDPOINT = "/web-ui/cloud-settings";

// TODO: Comment
const WEBUI_ALERTS_HISTORY_LEN = 10;

// Web UI class
class WebUI {
    // TODO: Comment
    _latestData = null;
    // TODO: Comment
    _alertsHistory = null;
    // TODO: Comment
    _tokensSetter = null;
    // TODO: Comment
    _cloudConfigurator = null;

    /**
     * Constructor for Web UI class
     *
     * TODO
     */
    constructor(tokensSetter, cloudConfigurator) {
        _tokensSetter = tokensSetter;
        _cloudConfigurator = cloudConfigurator;

        Rocky.on("GET", WEBUI_INDEX_PAGE_ENDPOINT, _getIndexPageRockyHandler.bindenv(this));
        Rocky.on("GET", WEBUI_DATA_ENDPOINT, _getDataRockyHandler.bindenv(this));
        Rocky.on("PATCH", WEBUI_TOKENS_ENDPOINT, _patchTokensRockyHandler.bindenv(this));
        Rocky.on("PATCH", WEBUI_CLOUD_SETTINGS_ENDPOINT, _patchCloudSettingsRockyHandler.bindenv(this));

        _alertsHistory = [];
    }

    // TODO: Comment
    function newData(data) {
        _latestData = data;

        foreach (alert in data.alerts) {
            _alertsHistory.insert(0, {
                "alert": alert,
                "ts": data.timestamp
            });
        }

        if (_alertsHistory.len() > WEBUI_ALERTS_HISTORY_LEN) {
            _alertsHistory.resize(WEBUI_ALERTS_HISTORY_LEN);
        }
    }

    // -------------------- PRIVATE METHODS -------------------- //

    // TODO: Comment
    function _getIndexPageRockyHandler(context) {
        ::debug("GET " + WEBUI_INDEX_PAGE_ENDPOINT + " request received", "@{CLASS_NAME}");

        // Return the index.html page file
        context.send(200, _indexHtml());
    }

    // TODO: Comment
    function _getDataRockyHandler(context) {
        ::debug("GET " + WEBUI_DATA_ENDPOINT + " request received", "@{CLASS_NAME}");

        local data = {
            "latestData": _latestData,
            "alertsHistory": _alertsHistory
        };

        // Return the data
        context.send(200, data);
    }

    // TODO: Comment
    function _patchTokensRockyHandler(context) {
        ::debug("PATCH " + WEBUI_TOKENS_ENDPOINT + " request received", "@{CLASS_NAME}");

        local tokens = context.req.body;
        local ubloxToken = "ublox" in tokens ? tokens.ublox : null;
        local gmapsKey   = "gmaps" in tokens ? tokens.gmaps : null;
        _tokensSetter(ubloxToken, gmapsKey);

        context.send(200);
    }

    // TODO: Comment
    function _patchCloudSettingsRockyHandler(context) {
        ::debug("PATCH " + WEBUI_CLOUD_SETTINGS_ENDPOINT + " request received", "@{CLASS_NAME}");

        local cloudSettings = context.req.body;
        _cloudConfigurator(cloudSettings.url, cloudSettings.user, cloudSettings.pass);

        context.send(200);
    }

    // TODO: Comment
    function _indexHtml() {
        return "@{include("WebUI/index.html") | escape}";
    }
}

@set CLASS_NAME = null // Reset the variable
