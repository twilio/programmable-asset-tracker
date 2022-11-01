// MIT License

// Copyright (C) 2022, Twilio, Inc. <help@twilio.com>

// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do
// so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

@set CLASS_NAME = "Photoresistor" // Class name for logging

// Default polling period, in seconds
const PR_DEFAULT_POLL_PERIOD = 1.0;
// The value that indicates that the light was detected
const PR_LIGHT_DETECTED_VALUE = 1;

// Photoresistor class.
// Used to poll a photoresistor
class Photoresistor {
    _valPin = null;
    _switchPin = null;
    _pollTimer = null;

    /**
     * Constructor for Photoresistor class
     *
     * @param {object} switchPin - Hardware pin object that switches power of the photoresistor
     * @param {object} valPin - Hardware pin object used for reading the photoresistor's state/value
     */
    constructor(switchPin, valPin) {
        _switchPin = switchPin;
        _valPin = valPin;
    }

    /**
     * Start polling of the photoresistor
     *
     * @param {function} callback - Callback to be called when the state/value on the photoresistor is changed
     * @param {float} [pollPeriod = PR_DEFAULT_POLL_PERIOD] - Polling period
     */
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

    /**
     * Stop polling of the photoresistor
     */
    function stopPolling() {
        _pollTimer && imp.cancelwakeup(_pollTimer);
        _switchPin.disable();
        _valPin.disable();

        ::debug("Polling stopped", "@{CLASS_NAME}");
    }
}

@set CLASS_NAME = null // Reset the variable
