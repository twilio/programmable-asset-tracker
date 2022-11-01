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

@set CLASS_NAME = "LedIndication" // Class name for logging

// Duration of a signal, in seconds
const LI_SIGNAL_DURATION = 1.0;
// Duration of a gap (delay) between signals, in seconds
const LI_GAP_DURATION = 0.2;
// Maximum repeats of the same event in a row
const LI_MAX_EVENT_REPEATS = 3;

// Event type for indication
enum LI_EVENT_TYPE {
    // Format: 0xRGB. E.g., 0x010 = GREEN, 0x110 = YELLOW
    // Green
    NEW_MSG = 0x010,
    // Red
    ALERT_SHOCK = 0x100,
    // White
    ALERT_MOTION_STARTED = 0x111,
    // Cyan
    ALERT_MOTION_STOPPED = 0x011,
    // Blue
    ALERT_TEMP_LOW = 0x001,
    // Yellow
    ALERT_TEMP_HIGH = 0x110,
    // Magenta
    MOVEMENT_DETECTED = 0x101
}

// LED indication class.
// Used for LED-indication of different events
class LedIndication {
    // Array of pins for blue, green and red (exactly this order) colors
    _rgbPins = null;
    // Promise used instead of a queue of signals for simplicity
    _indicationPromise = Promise.resolve(null);
    // The last indicated event type
    _lastEventType = null;
    // The number of repeats (in a row) of the last indicated event
    _lastEventRepeats = 0;

    /**
     * Constructor LED indication
     *
     * @param {object} rPin - Pin object used to control the red LED.
     * @param {object} gPin - Pin object used to control the green LED.
     * @param {object} bPin - Pin object used to control the blue LED.
     */
    constructor(rPin, gPin, bPin) {
        // Inverse order for convenience
        _rgbPins = [bPin, gPin, rPin];
    }

    /**
     * Indicate an event using LEDs
     *
     * @param {LI_EVENT_TYPE} eventType - The event type to indicate.
     */
    function indicate(eventType) {
        // There are 3 LEDS: blue, green, red
        const LI_LEDS_NUM = 3;

        if (eventType == _lastEventType) {
            _lastEventRepeats++;
        } else {
            _lastEventType = eventType;
            _lastEventRepeats = 0;
        }

        if (_lastEventRepeats >= LI_MAX_EVENT_REPEATS) {
            return;
        }

        _indicationPromise = _indicationPromise
        .finally(function(_) {
            // Turn on the required colors
            for (local i = 0; i < LI_LEDS_NUM && eventType > 0; i++) {
                (eventType & 1) && _rgbPins[i].configure(DIGITAL_OUT, 1);
                eventType = eventType >> 4;
            }

            return Promise(function(resolve, reject) {
                local stop = function() {
                    for (local i = 0; i < LI_LEDS_NUM; i++) {
                        _rgbPins[i].disable();
                    }

                    // Decrease the counter of repeats since we now have time for one more signal
                    (_lastEventRepeats > 0) && _lastEventRepeats--;

                    // Make a gap (delay) between signals for better perception
                    imp.wakeup(LI_GAP_DURATION, resolve);
                }.bindenv(this);

                // Turn off all colors after the signal duration
                imp.wakeup(LI_SIGNAL_DURATION, stop);
            }.bindenv(this));
        }.bindenv(this));
    }
}

@set CLASS_NAME = null // Reset the variable
