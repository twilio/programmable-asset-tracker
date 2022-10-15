#require "rocky.agent.lib.nut:3.0.1"
#require "Messenger.lib.nut:0.2.0"

@include once "../src/shared/Logger/Logger.shared.nut"

// API endpoint prefix
const APP_REST_API_DATA_ENDPOINT_PREFIX = "/esp32-";
// Swith off ESP32
const APP_REST_API_DATA_ENDPOINT_FINISH = "finish";
// Endpoint firmware load
const APP_REST_API_DATA_ENDPOINT_LOAD = "load";
// Firmware flash address length
const APP_FW_ADDR_LEN = 4;
// Timeout to re-check connection with imp-device, in seconds
const APP_CHECK_IMP_CONNECT_TIMEOUT = 15;
// Firmware image portion send size
const APP_DATA_PORTION_SIZE = 8192;
// MD5 string length
const APP_DATA_MD5_LEN = 32;

// Returned HTTP codes
enum APP_REST_API_HTTP_CODES {
    OK = 200,           // Success
    INVALID_REQ = 400,  // Error
    TOO_MANY_REQ = 429, // Too many requests
    SERVICE_UNAVAILABLE = 503 // Service temporarily unavailable
};

// Messenger message names
enum APP_M_MSG_NAME {
    INFO = "info",
    DATA = "data",
    ESP_FINISH = "finish"
};

// ESP32 loader example agent application
class Application {
    // Messenger instance
    _msngr = null;
    // Timer to re-check connection with imp-device
    _timerSending = null;
    // MD5 values of firmware image
    _md5Sum = null;
    // Firmware file
    _fwImage = null;
    // Timer to re-check connection with imp-device
    _timerSending = null;
    // Current file name
    _fileName = null;
    // ESP32 flash address
    _offset = null;
    // firmware image length
    _fileLen = null;
    // firmware image data portion
    _portion = null;

    /**
     * Application Constructor
     */
    constructor() {
        // Initialize library for communication with Imp-Device
        _initMsngr();
        // Initialize REST API library
        _initRocky();
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Create and initialize Messenger instance
     */
    function _initMsngr() {
        _msngr = Messenger();
        _msngr.onAck(_ackCb.bindenv(this));
        _msngr.onFail(_failCb.bindenv(this));
    }

    /**
     * Initialize Rocky instance
     */
    function _initRocky() {
        Rocky.init();
        Rocky.on("PUT",
                 APP_REST_API_DATA_ENDPOINT_PREFIX +
                 APP_REST_API_DATA_ENDPOINT_LOAD,
                 _putRockyHandlerLoad.bindenv(this));
        Rocky.on("PUT",
                 APP_REST_API_DATA_ENDPOINT_PREFIX +
                 APP_REST_API_DATA_ENDPOINT_FINISH,
                 _putRockyHandlerFinish.bindenv(this));
    }

    /**
     * HTTP PUT request callback function load endpoint.
     *
     * @param context - Rocky.Context object
     */
    function _putRockyHandlerLoad(context) {
        ::info("PUT " + context.req.path + " request from cloud");

        local req = context.req;

        if (!("content-length" in req.headers)) {
            ::error("Content length is unknown");
            context.send(APP_REST_API_HTTP_CODES.INVALID_REQ);
            return;
        }

        try {
            _fileName = req.query.fileName;
            _offset = req.query.flashOffset.tointeger();

            if ("md5" in req.query &&
                req.query.md5.len() == APP_DATA_MD5_LEN) {
                _md5Sum = req.query.md5;
            } else {
                _md5Sum = null;
            }
        } catch (err) {
            ::error("Firmware description set failure: " + err);
            return context.send(APP_REST_API_HTTP_CODES.INVALID_REQ);
        }

        local fwLen = req.headers["content-length"].tointeger();
        local fwBlob = blob();
        fwBlob.writestring(req.body);
        fwBlob.seek(0, 'b');

        if (fwLen != fwBlob.len()) {
            ::error("Content length header value is not equal to the body length");
            return context.send(APP_REST_API_HTTP_CODES.INVALID_REQ);
        }

        // save firmware image
        _fwImage = fwBlob;
        _fileLen = fwLen;

        local onSuccess = @() context.send(APP_REST_API_HTTP_CODES.OK);
        local onFail = @() context.send(APP_REST_API_HTTP_CODES.SERVICE_UNAVAILABLE);

        _sendInfo(onSuccess, onFail);
    }

    /**
     * Send firmware file info to imp-device.
     *
     * @param {function} onSuccess - Callback to be called on success request execution.
     * @param {function} onFail - Callback to be called on failure request execution.
     */
    function _sendInfo(onSuccess, onFail) {
        if (device.isconnected()) {
            local data = {
                "fileName" : _fileName,
                "fileLen"  : _fileLen,
                "offs"     : _offset,
                "md5"      : _md5Sum
            };

            local metadata = {
                "onSuccess" : onSuccess,
                "onFail"    : onFail
            };

            _msngr.send(APP_M_MSG_NAME.INFO, data, null, metadata);
        } else {
            onFail();
        }
    }

    /**
     * HTTP PUT request callback function finish endpoint.
     *
     * @param context - Rocky.Context object
     */
    function _putRockyHandlerFinish(context) {
        ::info("PUT " + context.req.path + " request from cloud");

        _sendFinish();
        context.send(APP_REST_API_HTTP_CODES.OK);
    }

    /**
     * Send finish command to the ESP32.
     */
    function _sendFinish() {
        if (device.isconnected()) {
            _msngr.send(APP_M_MSG_NAME.ESP_FINISH, null);
        } else {
            // Device is disconnected =>
            // check the connection again after the timeout
            _timerSending && imp.cancelwakeup(_timerSending);
            _timerSending = imp.wakeup(APP_CHECK_IMP_CONNECT_TIMEOUT,
                                       _sendFinish.bindenv(this));
        }
    }

    /**
     * Send firmware file to imp-device.
     */
    function _sendData() {
        if (device.isconnected()) {
            _msngr.send(APP_M_MSG_NAME.DATA, _portion);
        } else {
            // Device is disconnected =>
            // check the connection again after the timeout
            _timerSending && imp.cancelwakeup(_timerSending);
            _timerSending = imp.wakeup(APP_CHECK_IMP_CONNECT_TIMEOUT,
                                       _sendData.bindenv(this));
        }
    }

    /**
     * Callback that is triggered when a message sending fails.
     *
     * @param msg - Messenger.Message object.
     * @param {string} error - A description of the message failure.
     */
    function _failCb(msg, error) {
        local name = msg.payload.name;
        if (name == APP_M_MSG_NAME.INFO) {
            msg.metadata.onFail();
        }

        if (name == APP_M_MSG_NAME.DATA) {
            _sendData();
        }
    }

    /**
     * Callback that is triggered when a message is acknowledged.
     *
     * @param msg - Messenger.Message object.
     * @param ackData - Any serializable type -
     *                  The data sent in the acknowledgement, or null if no data was sent
     */
    function _ackCb(msg, ackData) {
        local name = msg.payload.name;

        if (name == APP_M_MSG_NAME.INFO) {
            msg.metadata.onSuccess();
        }

        if (name != APP_M_MSG_NAME.ESP_FINISH) {
            local curPos = _fwImage.tell();
            local remain = _fileLen - curPos;

            if (remain > 0) {
                _portion = {"fwData" : _fwImage.readblob(APP_DATA_PORTION_SIZE),
                            "position" : curPos};
                _sendData();
            }
        }
    }
}

// ---------------------------- THE MAIN CODE ---------------------------- //

::info("ESP32 loader example agent start");
// Run the application
app <- Application();
