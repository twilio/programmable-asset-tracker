@set CLASS_NAME = "CustomReplayMessenger" // Class name for logging

// Customized ReplayMessenger library

// Maximum number of recent messages to look into when searching the maximum message ID
const CRM_MAX_ID_SEARCH_DEPTH = 20;
// Minimum free memory (bytes) to allow SPI flash logger reading and resending persisted messages
const CRM_FREE_MEM_THRESHOLD = 81920;
// Custom value for MSGR_QUEUE_CHECK_INTERVAL_SEC
const CRM_QUEUE_CHECK_INTERVAL_SEC = 1.0;
// Custom value for RM_RESEND_RATE_LIMIT_PCT
const CRM_RESEND_RATE_LIMIT_PCT = 80;

class CustomReplayMessenger extends ReplayMessenger {
    _persistedMessagesPending = false;
    _eraseAllPending = false;
    _onIdleCb = null;
    _onAckCbs = null;
    _onAckDefaultCb = null;
    _onFailCbs = null;
    _onFailDefaultCb = null;

    constructor(spiFlashLogger, options = {}) {
        // Provide any ID to prevent the standart algorithm of searching of the next usable ID
        options.firstMsgId <- 0;

        base.constructor(spiFlashLogger, cm, options);

        // Override the resend rate variable using our custom constant
        _maxResendRate = _maxRate * CRM_RESEND_RATE_LIMIT_PCT / 100;

        // We want to block any background RM activity until the initialization is done
        _readingInProcess = true;

        // In the custom version, we want to have an individual ACK and Fail callback for each message name
        _onAck = _onAckHandler;
        _onAckCbs = {};
        _onFail = _onFailHandler;
        _onFailCbs = {};
    }

    function init(onDone) {
        local maxId = -1;
        local msgRead = 0;

        _log(format("Reading %d recent messages to find the maximum message ID...", CRM_MAX_ID_SEARCH_DEPTH));
        local start = hardware.millis();

        local onData = function(payload, address, next) {
            local id = -1;

            try {
                id = payload[RM_COMPRESSED_MSG_PAYLOAD]["id"];
            } catch (err) {
                ::error("Corrupted message detected during initialization: " + err, "@{CLASS_NAME}");
                _spiFL.erase(address);
                next();
                return;
            }

            maxId = id > maxId ? id : maxId;
            msgRead++;
            next(msgRead < CRM_MAX_ID_SEARCH_DEPTH);
        }.bindenv(this);

        local onFinish = function() {
            local elapsed = hardware.millis() - start;
            _log(format("The maximum message ID has been found: %d. Elapsed: %dms", maxId, elapsed));

            _nextId = maxId + 1;
            _readingInProcess = false;
            _persistedMessagesPending = msgRead > 0;
            _setTimer();
            onDone();
        }.bindenv(this);

        // We are going to read CRM_MAX_ID_SEARCH_DEPTH messages starting from the most recent one
        _spiFL.read(onData, onFinish, -1);
    }

    function onAck(cb, name = null) {
        if (name == null) {
            _onAckDefaultCb = cb;
        } else if (cb) {
            _onAckCbs[name] <- cb;
        } else if (name in _onAckCbs) {
            delete _onAckCbs[name];
        }
    }

    function onFail(cb, name = null) {
        if (name == null) {
            _onFailDefaultCb = cb;
        } else if (cb) {
            _onFailCbs[name] <- cb;
        } else if (name in _onFailCbs) {
            delete _onFailCbs[name];
        }
    }

    function readyToSend() {
        return _cm.isConnected() && _checkSendLimits();
    }

    function hasPersistedMessages() {
        return _persistedMessagesPending;
    }

    function isIdle() {
        return _isAllProcessed();
    }

    // Registers a callback which will be called when _isAllProcessed() turns false
    function onIdle(cb) {
        _onIdleCb = cb;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    // Sends the message (and immediately persists it if needed) and restarts the timer for processing the queues
    function _send(msg) {
        // Check if the message has importance = RM_IMPORTANCE_CRITICAL and not yet persisted
        if (msg._importance == RM_IMPORTANCE_CRITICAL && !_isMsgPersisted(msg)) {
            _persistMessage(msg);
        }

        local id = msg.payload.id;
        _log("Trying to send msg. Id: " + id);

        local now = _monotonicMillis();
        if (now - 1000 > _lastRateMeasured || now < _lastRateMeasured) {
            // Reset the counters if the timer's overflowed or
            // more than a second passed from the last measurement
            _rateCounter = 0;
            _lastRateMeasured = now;
        } else if (_rateCounter >= _maxRate) {
            // Rate limit exceeded, raise an error
            _onSendFail(msg, MSGR_ERR_RATE_LIMIT_EXCEEDED);
            return;
        }

        // Try to send
        local payload = msg.payload;
        local err = _partner.send(MSGR_MESSAGE_TYPE_DATA, payload);
        if (!err) {
            // Send complete
            _log("Sent. Id: " + id);

            _rateCounter++;
            // Set sent time, update sentQueue and restart timer
            msg._sentTime = time();
            _sentQueue[id] <- msg;

            _log(format("_sentQueue: %d, _persistMessagesQueue: %d, _eraseQueue: %d", _sentQueue.len(), _persistMessagesQueue.len(), _eraseQueue.len()));

            _setTimer();
        } else {
            _log("Sending error. Code: " + err);
            // Sending failed
            _onSendFail(msg, MSGR_ERR_NO_CONNECTION);
        }
    }

    function _onAckHandler(msg, data) {
        local name = msg.payload.name;

        if (name in _onAckCbs) {
            _onAckCbs[name](msg, data);
        } else {
            _onAckDefaultCb && _onAckDefaultCb(msg, data);
        }
    }

    function _onFailHandler(msg, error) {
        local name = msg.payload.name;

        if (name in _onFailCbs) {
            _onFailCbs[name](msg, error);
        } else {
            _onFailDefaultCb && _onFailDefaultCb(msg, error);
        }
    }

    // Returns true if send limits are not exceeded, otherwise false
    function _checkSendLimits() {
        local now = _monotonicMillis();
        if (now - 1000 > _lastRateMeasured || now < _lastRateMeasured) {
            // Reset the counters if the timer's overflowed or
            // more than a second passed from the last measurement
            _rateCounter = 0;
            _lastRateMeasured = now;
        } else if (_rateCounter >= _maxRate) {
            // Rate limit exceeded
            _log("Send rate limit exceeded");
            return false;
        }

        return true;
    }

    function _isAllProcessed() {
        if (_sentQueue.len() != 0) {
            return false;
        }

        // We can't process persisted messages if we are offline
        return !_cm.isConnected() || !_persistedMessagesPending;
    }

    // Processes both _sentQueue and the messages persisted on the flash
    function _processQueues() {
        // Clean up the timer
        _queueTimer = null;

        local now = time();

        // Call onFail for timed out messages
        foreach (id, msg in _sentQueue) {
            local ackTimeout = msg._ackTimeout ? msg._ackTimeout : _ackTimeout;
            if (now - msg._sentTime >= ackTimeout) {
                _onSendFail(msg, MSGR_ERR_ACK_TIMEOUT);
            }
        }

        _processPersistedMessages();

        // Restart the timer if there is something pending
        if (!_isAllProcessed()) {
            _setTimer();
            // If Replay Messenger has unsent or unacknowledged messages, keep the connection for it
            cm.keepConnection("@{CLASS_NAME}", true);
        } else {
            _onIdleCb && _onIdleCb();
            // If Replay Messenger is idle (has no unsent or unacknowledged messages), it doesn't need the connection anymore
            cm.keepConnection("@{CLASS_NAME}", false);
        }
    }

    // Processes the messages persisted on the flash
    function _processPersistedMessages() {
        if (_readingInProcess || !_persistedMessagesPending || imp.getmemoryfree() < CRM_FREE_MEM_THRESHOLD) {
            return;
        }

        local sectorToCleanup = null;
        local messagesExist = false;

        if (_cleanupNeeded) {
            sectorToCleanup = _flDimensions["start"] + (_spiFL.getPosition() / _flSectorSize + 1) * _flSectorSize;

            if (sectorToCleanup >= _flDimensions["end"]) {
                sectorToCleanup = _flDimensions["start"];
            }
        } else if (!_cm.isConnected() || !_checkResendLimits()) {
            return;
        }

        local onData = function(messagePayload, address, next) {
            local msg = null;

            try {
                // Create a message from payload
                msg = _messageFromFlash(messagePayload, address);
            } catch (err) {
                ::error("Corrupted message detected during processing messages: " + err, "@{CLASS_NAME}");
                _spiFL.erase(address);
                next();
                return;
            }

            messagesExist = true;
            local id = msg.payload.id;

            local needNextMsg = _cleanupPersistedMsg(sectorToCleanup, address, id, msg) ||
                                _resendPersistedMsg(address, id, msg);

            needNextMsg = needNextMsg && (imp.getmemoryfree() >= CRM_FREE_MEM_THRESHOLD);

            next(needNextMsg);
        }.bindenv(this);

        local onFinish = function() {
            _log("Processing persisted messages: finished");

            _persistedMessagesPending = messagesExist;

            if (sectorToCleanup != null) {
                _onCleanupDone();
            }
            _onReadingFinished();
        }.bindenv(this);

        _log("Processing persisted messages...");
        _readingInProcess = true;
        _spiFL.read(onData, onFinish);
    }

    // Callback called when async reading (in the _processPersistedMessages method) is finished
    function _onReadingFinished() {
        _readingInProcess = false;

        if (_eraseAllPending) {
            _eraseAllPending = false;
            _spiFL.eraseAll(true);
            ::debug("Flash logger erased", "@{CLASS_NAME}");

            _eraseQueue = {};
            _cleanupNeeded = false;
            _processPersistMessagesQueue();
        }

        // Process the queue of messages to be erased
        if (_eraseQueue.len() > 0) {
            _log("Processing the queue of messages to be erased...");
            foreach (id, address in _eraseQueue) {
                _log("Message erased. Id: " + id);
                _spiFL.erase(address);
            }
            _eraseQueue = {};
            _log("Processing the queue of messages to be erased: finished");
        }

        if (_cleanupNeeded) {
            // Restart the processing in order to cleanup the next sector
            _processPersistedMessages();
        }
    }

    // Persists the message if there is enough space in the current sector.
    // If not, adds the message to the _persistMessagesQueue queue (if `enqueue` is `true`).
    // Returns true if the message has been persisted, otherwise false
    function _persistMessage(msg, enqueue = true) {
        if (_cleanupNeeded) {
            if (enqueue) {
                _log("Message added to the queue to be persisted later. Id: " + msg.payload.id);
                _persistMessagesQueue.push(msg);

                _log(format("_sentQueue: %d, _persistMessagesQueue: %d, _eraseQueue: %d", _sentQueue.len(), _persistMessagesQueue.len(), _eraseQueue.len()));
            }
            return false;
        }

        local payload = _prepareMsgToPersist(msg);

        if (_isEnoughSpace(payload)) {
            msg._address = _spiFL.getPosition();

            try {
                _spiFL.write(payload);
            } catch (err) {
                // TODO: Erase only once!
                ::error("Couldn't persist a message: " + err, "@{CLASS_NAME}");
                ::error("Erasing the flash logger!", "@{CLASS_NAME}");

                if (_readingInProcess) {
                    ::debug("Flash logger will be erased once reading is finished", "@{CLASS_NAME}");
                    _eraseAllPending = true;
                    enqueue && _persistMessagesQueue.push(msg);
                } else {
                    _spiFL.eraseAll(true);
                    ::debug("Flash logger erased", "@{CLASS_NAME}");
                    // Instead of enqueuing, we try to write it again because erasing must help. If it doesn't help, we will just drop this message
                    enqueue && _persistMessage(msg, false);
                }

                _log(format("_sentQueue: %d, _persistMessagesQueue: %d, _eraseQueue: %d", _sentQueue.len(), _persistMessagesQueue.len(), _eraseQueue.len()));
                return false;
            }

            _log("Message persisted. Id: " + msg.payload.id);
            _persistedMessagesPending = true;
            return true;
        } else {
            _log("Need to clean up the next sector");
            _cleanupNeeded = true;
            if (enqueue) {
                _log("Message added to the queue to be persisted later. Id: " + msg.payload.id);
                _persistMessagesQueue.push(msg);

                _log(format("_sentQueue: %d, _persistMessagesQueue: %d, _eraseQueue: %d", _sentQueue.len(), _persistMessagesQueue.len(), _eraseQueue.len()));
            }
            _processPersistedMessages();
            return false;
        }
    }

    // Returns true if there is enough space in the current flash sector to persist the payload
    function _isEnoughSpace(payload) {
        local nextSector = (_spiFL.getPosition() / _flSectorSize + 1) * _flSectorSize;
        // NOTE: We need to access a private field for optimization
        // Correct work is guaranteed with "SPIFlashLogger.device.lib.nut:2.2.0"
        local payloadSize = _spiFL._serializer.sizeof(payload, SPIFLASHLOGGER_OBJECT_MARKER);

        if (_spiFL.getPosition() + payloadSize <= nextSector) {
            return true;
        } else {
            if (nextSector >= _flDimensions["end"] - _flDimensions["start"]) {
                nextSector = 0;
            }

            local nextSectorIdx = nextSector / _flSectorSize;
            // NOTE: We need to call a private method for optimization
            // Correct work is guaranteed with "SPIFlashLogger.device.lib.nut:2.2.0"
            local objectsStartCodes = _spiFL._getObjectsStartCodesForSector(nextSectorIdx);
            local nextSectorIsEmpty = objectsStartCodes == null || objectsStartCodes.len() == 0;
            return nextSectorIsEmpty;
        }
    }

    // Erases the message if no async reading is ongoing, otherwise puts it into the queue to erase later
    function _safeEraseMsg(id, msg) {
        if (!_readingInProcess) {
            _log("Message erased. Id: " + id);
            _spiFL.erase(msg._address);
        } else {
            _log("Message added to the queue to be erased later. Id: " + id);
            _eraseQueue[id] <- msg._address;

            _log(format("_sentQueue: %d, _persistMessagesQueue: %d, _eraseQueue: %d", _sentQueue.len(), _persistMessagesQueue.len(), _eraseQueue.len()));
        }
        msg._address = null;
    }

    // Sets a timer for processing queues
    function _setTimer() {
        if (_queueTimer) {
            // The timer is already running
            return;
        }
        _queueTimer = imp.wakeup(CRM_QUEUE_CHECK_INTERVAL_SEC,
                                _processQueues.bindenv(this));
    }

    // Implements debug logging. Sends the log message to the console output if "debug" configuration flag is set
    function _log(message) {
        if (_debug) {
            ::debug(message, "@{CLASS_NAME}");
        }
    }
}

@set CLASS_NAME = null // Reset the variable
