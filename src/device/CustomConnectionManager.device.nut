@set CLASS_NAME = "CustomConnectionManager" // Class name for logging

// Customized ConnectionManager library
class CustomConnectionManager extends ConnectionManager {
    _autoDisconnectDelay = null;
    _maxConnectedTime = null;

    _consumers = null;
    _connectPromise = null;
    _connectTime = null;
    _disconnectTimer = null;

    /**
     * Constructor for Customized Connection Manager
     *
     * @param {table} [settings = {}] - Key-value table with optional settings.
     *
     * An exception may be thrown in case of wrong settings.
     */
    constructor(settings = {}) {
        // Automatically disconnect if the connection is not consumed for some time
        _autoDisconnectDelay = "autoDisconnectDelay" in settings ? settings.autoDisconnectDelay : null;
        // Automatically disconnect if the connection is up for too long (for power saving purposes)
        _maxConnectedTime = "maxConnectedTime" in settings ? settings.maxConnectedTime : null;

        if ("stayConnected" in settings && settings.stayConnected && (_autoDisconnectDelay != null || _maxConnectedTime != null)) {
            throw "stayConnected option cannot be used together with automatic disconnection features";
        }

        base.constructor(settings);
        _consumers = [];
        _connectTime = hardware.millis();

        onConnect(_onConnectCb.bindenv(this), "@{CLASS_NAME}");
        onTimeout(_onConnectionTimeoutCb.bindenv(this), "@{CLASS_NAME}");
        onDisconnect(_onDisconnectCb.bindenv(this), "@{CLASS_NAME}");
    }

    /**
     * Connect to the server. Set the disconnection timer if needed.
     * If already connected:
     *   - the onConnect handler will NOT be called
     *   - if the disconnection timer was set, it will be cancelled and set again
     *
     * @return {Promise} that:
     * - resolves if the operation succeeded
     * - rejects with if the operation failed
     */
    function connect() {
        if (_connected) {
            _setDisconnectTimer();
            return Promise.resolve(null);
        }

        if (_connectPromise) {
            return _connectPromise;
        }

        ::info("Connecting..", "@{CLASS_NAME}");

        local baseConnect = base.connect;

        _connectPromise = Promise(function(resolve, reject) {
            onConnect(resolve, "@{CLASS_NAME}.connect");
            onTimeout(reject, "@{CLASS_NAME}.connect");
            onDisconnect(reject, "@{CLASS_NAME}.connect");

            baseConnect();
        }.bindenv(this));

        // A workaround to avoid "Unhandled promise rejection" message in case of connection failure
        _connectPromise
        .fail(@(_) null);

        return _connectPromise;
    }

    /**
     * Keep/don't keep the connection (if established) while a consumer is using it.
     * If there is at least one consumer using the connection, automatic disconnection is deactivated.
     * Once there are no consumers, automatic disconnection is activated.
     * May be called when connectected and when disconnected as well
     *
     * @param {string} consumerId - Consumer's identificator.
     * @param {boolean} keep - Flag indicating if the connection should be kept for this consumer.
     */
    function keepConnection(consumerId, keep) {
        // It doesn't make sense to manage the list of connection consumers if the autoDisconnectDelay option is disabled
        if (_autoDisconnectDelay == null) {
            return;
        }

        local idx = _consumers.find(consumerId);

        if (keep && idx == null) {
            ::debug("Connection will be kept for " + consumerId, "@{CLASS_NAME}");
            _consumers.push(consumerId);
            _connected && _setDisconnectTimer();
        } else if (!keep && idx != null) {
            ::debug("Connection will not be kept for " + consumerId, "@{CLASS_NAME}");
            _consumers.remove(idx);
            _connected && _setDisconnectTimer();
        }
    }

    /**
     * Callback called when a connection to the server has been established
     * NOTE: This function can't be renamed to _onConnect
     */
    function _onConnectCb() {
        ::info("Connected", "@{CLASS_NAME}");
        _connectPromise = null;
        _connectTime = hardware.millis();

        _setDisconnectTimer();
    }

    /**
     * Callback called when a connection to the server has been timed out
     * NOTE: This function can't be renamed to _onConnectionTimeout
     */
    function _onConnectionTimeoutCb() {
        ::info("Connection timeout", "@{CLASS_NAME}");
        _connectPromise = null;
    }

    /**
     * Callback called when a connection to the server has been broken
     * NOTE: This function can't be renamed to _onDisconnect
     *
     * @param {boolean} expected - Flag indicating if the disconnection was expected
     */
    function _onDisconnectCb(expected) {
        ::info(expected ? "Disconnected" : "Disconnected unexpectedly", "@{CLASS_NAME}");
        _disconnectTimer && imp.cancelwakeup(_disconnectTimer);
        _connectPromise = null;
    }

    /**
     * Set the disconnection timer according to the parameters of automatic disconnection features
     */
    function _setDisconnectTimer() {
        local delay = null;

        if (_maxConnectedTime != null) {
            delay = _maxConnectedTime - (hardware.millis() - _connectTime) / 1000.0;
        }

        if (_autoDisconnectDelay != null && _consumers.len() == 0) {
            delay = delay > _autoDisconnectDelay ? _autoDisconnectDelay : delay;
        }

        _disconnectTimer && imp.cancelwakeup(_disconnectTimer);

        if (delay != null) {
            ::debug(format("Disconnection scheduled in %d seconds", delay), "@{CLASS_NAME}");
            _disconnectTimer = imp.wakeup(delay, disconnect.bindenv(this));
        }
    }
}

@set CLASS_NAME = null // Reset the variable
