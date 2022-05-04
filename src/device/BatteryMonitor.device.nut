@set CLASS_NAME = "BatteryMonitor" // Class name for logging

// Measures the battery level
class BatteryMonitor {
    _fg = null;

    constructor(i2c) {
        if ("MAX17055" in getroottable()) {
            _fg = MAX17055(i2c);
        }
    }

    // Initializes the driver and starts measuring battery in order to determine the battery state
    function init() {
        ::info("BatteryMonitor initialization", "@{CLASS_NAME}");

        if (!_fg) {
            ::info("MAX17055 is not used - no battery measurements will be made", "@{CLASS_NAME}");
            return Promise.resolve(null);
        }

        local settings = {
            "desCap"       : 3500, // mAh
            "senseRes"     : 0.01, // ohms
            "chrgTerm"     : 256,   // mA
            "emptyVTarget" : 3.3,  // V
            "recoveryV"    : 3.88, // V
            "chrgV"        : MAX17055_V_CHRG_4_2,
            "battType"     : MAX17055_BATT_TYPE.LiCoO2
        };

        return Promise(function(resolve, reject) {
            local onDone = function(err) {
                err ? reject(err) : resolve(err);
            }.bindenv(this);

            _fg.init(settings, onDone);
        }.bindenv(this));
    }

    // The result is a table { "capacity": <cap>, "percent": <pct> }
    function measureBattery() {
        if (!_fg) {
            throw "No fuel gauge used";
        }

        return _fg.getStateOfCharge().percent;
    }
}

@set CLASS_NAME = null // Reset the variable
