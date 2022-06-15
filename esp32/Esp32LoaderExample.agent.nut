#require "rocky.agent.lib.nut:3.0.1"
#require "Promise.lib.nut:4.0.0"
#require "Messenger.lib.nut:0.2.0"

@include once "../src/shared/Logger/Logger.shared.nut"

// API endpoint prefix
const APP_REST_API_DATA_ENDPOINT_PREFIX = "/esp32-";
// Reboot ESP32 if in loader
const APP_REST_API_DATA_ENDPOINT_REBOOT = "reboot";
// Example API endpoint (file name and offset in ESP flash)
APP_REST_API_DATA_ENDPOINTS <- {"partition-table"   : 0x8000,
                                "ota_data_initial"  : 0x10000, 
                                "phy_init_data"     : 0xf000,
                                "bootloader"        : 0x1000, 
                                "esp-at"            : 0x100000,
                                "at_customize"      : 0x20000,
                                "ble_data"          : 0x21000,
                                "server_cert"       : 0x24000,
                                "server_key"        : 0x26000,
                                "server_ca"         : 0x28000,
                                "client_cert"       : 0x2a000,
                                "client_key"        : 0x2c000,
                                "client_ca"         : 0x2e000,
                                "mqtt_cert"         : 0x37000,
                                "mqtt_key"          : 0x39000,
                                "mqtt_ca"           : 0x3B000,
                                "factory_param"     : 0x30000};

// Firmware flash address length
const APP_FW_ADDR_LEN = 4;
// Timeout to re-check connection with imp-device, in seconds
const APP_CHECK_IMP_CONNECT_TIMEOUT = 15;
// Firmware image portion send size
const APP_DATA_PORTION_SIZE = 100; 

// Returned HTTP codes
enum APP_REST_API_HTTP_CODES {
    OK = 200,           // Cfg update is accepted (enqueued)
    INVALID_REQ = 400,  // Incorrect cfg
    TO_MANY_REQ = 429   // Too many requests
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
    // MD5 values of firmware images
    _md5Sums = null;
    // Firmware files
    _fwImages = null;
    // load process is active 
    _isActive = null;
    // Timer to re-check connection with imp-device
    _timerSending = null;
    // Current work endpoint
    _workEndpoint = null;
    // ESP32 flash address 
    _offsets = null;
    // firmware image length
    _lens = null;
    // firmware image data portion
    _portion = null;

    /**
     * Application Constructor
     */
    constructor() {
        _md5Sums = {};
        _fwImages = {};
        _offsets = {};
        _lens = {};
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
                 APP_REST_API_DATA_ENDPOINT_REBOOT, 
                 _putRockyHandler.bindenv(this));
        foreach (name, offs in APP_REST_API_DATA_ENDPOINTS) {
            Rocky.on("PUT", 
                     APP_REST_API_DATA_ENDPOINT_PREFIX + 
                     name, 
                     _putRockyHandler.bindenv(this));
        }
    }

    /**
     * HTTP PUT request callback function.
     *
     * @param context - Rocky.Context object
     */
    function _putRockyHandler(context) {
        ::info("PUT " + context.req.path + " request from cloud");

        // firmware loaded
        if (_isActive) {
            ::info("Previous request in progress");
            context.send(APP_REST_API_HTTP_CODES.TO_MANY_REQ);
            return;
        }

        _isActive = true;
        _workEndpoint = context.req.path.slice(APP_REST_API_DATA_ENDPOINT_PREFIX.len());

        if (_workEndpoint == APP_REST_API_DATA_ENDPOINT_REBOOT) {
            _isActive = false;
            _sendReboot();
            context.send(APP_REST_API_HTTP_CODES.OK);
            return;
        }

        local req = context.req;
        // extract MD5 if exist
        if ("content-md5" in req.headers) {
            _md5Sums[_workEndpoint] <- http.base64decode(req.headers["content-md5"]).tostring();
        } else {
            _md5Sums[_workEndpoint] <- null;
        }
        local fwLen = req.headers["content-length"].tointeger();
        local fwBlob = blob();
        fwBlob.writestring(req.body);
        fwBlob.seek(0, 'b');

        local offs = _endpoint2offs();
        if (offs < 0) {
            _isActive = false;
            context.send(APP_REST_API_HTTP_CODES.INVALID_REQ);
            return;
        }
        // set length
        _lens[_workEndpoint] <- fwLen;
        // firmware offset in flash
        _offsets[_workEndpoint] <- offs;
        // save firmware image
        _fwImages[_workEndpoint] <- fwBlob;

        // Return response to the cloud
        context.send(APP_REST_API_HTTP_CODES.OK);
        // send to imp-device
        _sendInfo();
    }

    /**
     * Get offset value from endpoint name.
     *
     * @return {integer} - Offset value in ESP32 flash.
     */
    function _endpoint2offs() {
        local offs = -1;
        foreach (name, val in APP_REST_API_DATA_ENDPOINTS) {
            if (_workEndpoint == name) {
                offs = val;
                break;
            }
        }

        if (offs == -1) ::error("Unknown offset!");

        return offs;
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
            _msngr.send(APP_M_MSG_NAME.INFO, {"fileName" : _workEndpoint, 
                                              "fileLen"  : _lens[_workEndpoint],
                                              "offs"     : _offsets[_workEndpoint],
                                              "md5"      : _md5Sums[_workEndpoint]});
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
     * Handler for status received from Imp-Agent
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
            local remain = _lens[_workEndpoint] - 
                           _fwImages[_workEndpoint].tell();
            if (remain > 0) {
                _portion = _fwImages[_workEndpoint].readblob(remain > APP_DATA_PORTION_SIZE ? 
                            APP_DATA_PORTION_SIZE : 
                            remain);
                _sendData();
            }
        }
    }
}

// ---------------------------- THE MAIN CODE ---------------------------- //

::info("ESP32 loader example agent start");
// Run the application
app <- Application();
