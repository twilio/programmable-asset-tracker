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

@set CLASS_NAME = "BatteryMonitor" // Class name for logging

// Delay (sec) between reads when getting the average value
const BM_AVG_DELAY = 0.8;
// Number of reads for getting the average value
const BM_AVG_SAMPLES = 6;
// Voltage gain according to the voltage divider
const BM_VOLTAGE_GAIN = 2.4242;

// 3 x 1.5v battery
const BM_FULL_VOLTAGE = 4.2;

// Battery class:
// - Reads battery voltage (several times with a delay)
// - Converts it to remaining capacity (%)
class BatteryMonitor {
    _batLvlEnablePin = null;
    _batLvlPin = null;
    _measuringBattery = null;

    // Voltage (normalized to 0-1 range) -> remaining capacity (normalized to 0-1 range)
    // Must be sorted by descending of Voltage
    _calibrationTable = [
        [1.0,     1.0],
        [0.975,   0.634],
        [0.97357, 0.5405],
        [0.94357, 0.44395],
        [0.94214, 0.37677],
        [0.90143, 0.21877],
        [0.86786, 0.13403],
        [0.82571, 0.06954],
        [0.79857, 0.04018],
        [0.755,   0.01991],
        [0.66071, 0.00236],
        [0.0,     0.0]
    ];

    /**
     * Constructor for Battery Monitor class
     *
     * @param {object} batLvlEnablePin - Hardware pin object that enables battery level measurement circuit
     * @param {object} batLvlPin - Hardware pin object that measures battery level (voltage)
     */
    constructor(batLvlEnablePin, batLvlPin) {
        _batLvlEnablePin = batLvlEnablePin;
        _batLvlPin = batLvlPin;
    }

    /**
     * Measure battery level
     *
     * @return {Promise} that resolves with the result of the battery measuring.
     *  The result is a table { "percent": <pct>, "voltage": <V> }
     */
    function measureBattery() {
        if (_measuringBattery) {
            return _measuringBattery;
        }

        _batLvlEnablePin.configure(DIGITAL_OUT, 1);
        _batLvlPin.configure(ANALOG_IN);

        return _measuringBattery = Promise(function(resolve, reject) {
            local measures = 0;
            local sumVoltage = 0;

            local measure = null;
            measure = function() {
                // Sum voltage to get the average value
                // Vbat = PinVal / 65535 * hardware.voltage() * (220k + 180k) / 180k
                sumVoltage += (_batLvlPin.read() / 65535.0) * hardware.voltage();
                measures++;

                if (measures < BM_AVG_SAMPLES) {
                    imp.wakeup(BM_AVG_DELAY, measure);
                } else {
                    _batLvlEnablePin.disable();
                    _batLvlPin.disable();
                    _measuringBattery = null;

                    // There is a voltage divider
                    local avgVoltage = sumVoltage * BM_VOLTAGE_GAIN / BM_AVG_SAMPLES;

                    local level = _getBatteryLevelByVoltage(avgVoltage);
                    ::debug("Battery level (raw):", "@{CLASS_NAME}");
                    ::debug(level, "@{CLASS_NAME}");

                    // Sampling complete, return result
                    resolve(level);
                }
            }.bindenv(this);

            measure();
        }.bindenv(this));
    }

    function _getBatteryLevelByVoltage(voltage) {
        local calTableLen = _calibrationTable.len();

        for (local i = 0; i < calTableLen; i++) {
            local point = _calibrationTable[i];
            local calVoltage = point[0] * BM_FULL_VOLTAGE;
            local calPercent = point[1] * 100.0;

            if (voltage < calVoltage) {
                continue;
            }

            if (i == 0) {
                return { "percent": 100.0, "voltage": voltage };
            }

            local prevPoint = _calibrationTable[i - 1];
            local prevCalVoltage = prevPoint[0] * BM_FULL_VOLTAGE;
            local prevCalPercent = prevPoint[1] * 100.0;

            // Calculate linear (y = k*x + b) coefficients, where x is Voltage and y is Percent
            local k = (calPercent - prevCalPercent) / (calVoltage - prevCalVoltage);
            local b = calPercent - k * calVoltage;

            local percent = k * voltage + b;

            return { "percent": percent, "voltage": voltage };
        }

        return { "percent": 0.0, "voltage": voltage };
    }
}

@set CLASS_NAME = null // Reset the variable
