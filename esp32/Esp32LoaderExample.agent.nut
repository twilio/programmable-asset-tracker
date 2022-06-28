#require "rocky.agent.lib.nut:3.0.1"
#require "Messenger.lib.nut:0.2.0"

@include once "../src/shared/Logger/Logger.shared.nut"

// API endpoint prefix
const APP_REST_API_DATA_ENDPOINT_PREFIX = "/esp32-";
// Reboot ESP32 if in loader
const APP_REST_API_DATA_ENDPOINT_REBOOT = "reboot";
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
    OK = 200,           // Cfg update is accepted (enqueued)
    INVALID_REQ = 400,  // Incorrect cfg
    TOO_MANY_REQ = 429  // Too many requests
};

// Messenger message names
enum APP_M_MSG_NAME {
    INFO = "info",
    DATA = "data",
    STATUS = "status",
    ESP_REBOOT = "reboot"
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
    // load process is active 
    _isActive = null;
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
        // inactive
        _isActive = false;
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
        _msngr.on(APP_M_MSG_NAME.STATUS, _onStatus.bindenv(this));
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
                 APP_REST_API_DATA_ENDPOINT_REBOOT, 
                 _putRockyHandlerReboot.bindenv(this));
    }

    /**
     * HTTP PUT request callback function load endpoint.
     *
     * @param context - Rocky.Context object
     */
    function _putRockyHandlerLoad(context) {
        ::info("PUT " + context.req.path + " request from cloud");

        local req = context.req;
        // firmware loaded
        if (_isActive) {
            ::info("Previous request in progress");
            context.send(APP_REST_API_HTTP_CODES.TOO_MANY_REQ);
            return;
        }

        if (!("content-length" in req.headers)) {
            ::error("Content length is unknown");
            context.send(APP_REST_API_HTTP_CODES.INVALID_REQ);
            return;
        }

        local ok = true;

        try {
            // set file name
            if ("fileName" in req.query) {
                _fileName = req.query.fileName;
            } else {
                ok = false;
            }

            // set length
            if ("fileLen" in req.query) {
                _fileLen = req.query.fileLen.tointeger();;
            } else {
                ok = false;    
            }

            // firmware offset in flash
            if ("flashOffset" in req.query) {
                _offset = req.query.flashOffset.tointeger();
            } else {
                ok = false;
            }

            if ("md5" in req.query && 
                req.query.md5.len() == APP_DATA_MD5_LEN) {
                _md5Sum = req.query.md5;    
            } else {
                _md5Sum = null;
            }
        } catch (err) {
            ::error("Firmware description set failure: " + err);
            ok = false;
        }
        // Return response to the cloud if error
        if (!ok) {
            _isActive = false;
            context.send(APP_REST_API_HTTP_CODES.INVALID_REQ);
            return;
        }

        local fwLen = req.headers["content-length"].tointeger();
        local fwBlob = blob();
        fwBlob.writestring(req.body);
        fwBlob.seek(0, 'b');

        if (fwLen != fwBlob.len()) {
            _isActive = false;
            ::error("Content length field not equil blob length");
            context.send(APP_REST_API_HTTP_CODES.INVALID_REQ);
            return;
        }

        // save firmware image
        _fwImage = fwBlob;
        // Return response to the cloud
        context.send(APP_REST_API_HTTP_CODES.OK);
        // send to imp-device
        _sendInfo();
    }

    /**
     * HTTP PUT request callback function reboot endpoint.
     *
     * @param context - Rocky.Context object
     */
    function _putRockyHandlerReboot(context) {
        ::info("PUT " + context.req.path + " request from cloud");

        // firmware loaded
        if (_isActive) {
            ::info("Previous request in progress");
            context.send(APP_REST_API_HTTP_CODES.TOO_MANY_REQ);
            return;
        }

        _sendReboot();
        context.send(APP_REST_API_HTTP_CODES.OK);
    }

    /**
     * Send reboot command to the ESP32.
     */
    function _sendReboot() {
        if (device.isconnected()) {
            _msngr.send(APP_M_MSG_NAME.ESP_REBOOT, null);
        } else {
            // Device is disconnected =>
            // check the connection again after the timeout
            _timerSending && imp.cancelwakeup(_timerSending);
            _timerSending = imp.wakeup(APP_CHECK_IMP_CONNECT_TIMEOUT,
                                       _sendReboot.bindenv(this));
        }
    }

    /**
     * Send firmware file info to imp-device.
     */
    function _sendInfo() {
        
        if (device.isconnected()) {
            _msngr.send(APP_M_MSG_NAME.INFO, {"fileName" : _fileName, 
                                              "fileLen"  : _fileLen,
                                              "offs"     : _offset,
                                              "md5"      : _md5Sum});
        } else {
            // Device is disconnected =>
            // check the connection again after the timeout
            _timerSending && imp.cancelwakeup(_timerSending);
            _timerSending = imp.wakeup(APP_CHECK_IMP_CONNECT_TIMEOUT,
                                       _sendInfo.bindenv(this));
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
     * Handler for status received from Imp-Device
     *
     * @param {table} msg - Received message payload.
     * @param customAck - Custom acknowledgment function.
     */
    function _onStatus(msg, customAck) {
        _isActive = false;
        ::info(msg.data);
    }

    /**
     * Callback that is triggered when a message sending fails.
     *
     * @param msg - Messenger.Message object.
     * @param {string} error - A description of the message failure.
     */
    function _failCb(msg, error) {
        local name = msg.payload.name;
        ::debug("Fail, name: " + name + ", error: " + error);
        if (name == APP_M_MSG_NAME.INFO) {
            // Send/resend 
            _sendInfo();
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
        if (name != APP_M_MSG_NAME.ESP_REBOOT) {
            local remain = _fileLen - 
                           _fwImage.tell();
            if (remain > 0) {
                _portion = _fwImage.readblob(APP_DATA_PORTION_SIZE);
                _sendData();
            }
        }
    }
}

// ---------------------------- THE MAIN CODE ---------------------------- //

::info("ESP32 loader example agent start");
// Run the application
app <- Application();
