@set CLASS_NAME = "Photoresistor" // Class name for logging

// Default polling period, in seconds
const PR_DEFAULT_POLL_PERIOD = 1.0;
// The value that indicates that the light was detected
const PR_LIGHT_DETECTED_VALUE = 1;

// TODO: Comment
class Photoresistor {
    _valPin = null;
    _switchPin = null;
    _pollTimer = null;

    // TODO: Comment
    constructor(switchPin, valPin) {
        _switchPin = switchPin;
        _valPin = valPin;
    }

    // TODO: Comment
    function startPolling(callback, pollPeriod = PR_DEFAULT_POLL_PERIOD) {
        stopPolling();

        ::debug("Starting polling.. Period = " + pollPeriod, "@{CLASS_NAME}");

        _switchPin.configure(DIGITAL_OUT, 1);
        _valPin.configure(DIGITAL_IN_WAKEUP);

        local poll;
        local detected = false;

        poll = function() {
            _pollTimer = imp.wakeup(pollPeriod, poll);

            if (detected != (_valPin.read() == PR_LIGHT_DETECTED_VALUE)) {
                detected = !detected;
                ::debug(detected ? "Light has been detected" : "No light detected anymore", "@{CLASS_NAME}");
                callback(detected);
            }
        }.bindenv(this);

        poll();
    }

    // TODO: Comment
    function stopPolling() {
        _pollTimer && imp.cancelwakeup(_pollTimer);
        _switchPin.disable();
        _valPin.disable();

        ::debug("Polling stopped", "@{CLASS_NAME}");
    }
}

@set CLASS_NAME = null // Reset the variable
