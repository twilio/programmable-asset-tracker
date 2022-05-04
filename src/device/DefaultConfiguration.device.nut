{
  "updateId": "myDefaultCfg",

  "locationTracking": {

    "locReadingPeriod": 180.0   // how often the tracker reads location when location obtaining is activated, in seconds

    "alwaysOn": false,          // true - location obtaining is always activated

    "motionMonitoring": {
      "enabled": true,          // true - motion monitoring is enabled
      "movementAccMin": 0.2,    // minimum (starting) acceleration threshold for movement detection, in g
      "movementAccMax": 0.4,    // maximum  acceleration threshold for movement detection, in g
      "movementAccDur": 0.25,   // duration of exceeding movement acceleration threshold, in seconds
      "motionTime": 15.0,       // maximum time to confirm motion detection after the initial movement, in seconds
      "motionVelocity": 0.5,    // minimum instantaneous velocity to confirm motion detection condition, in meters per second
      "motionDistance": 5.0,    // minimum movement distance to determine motion detection condition, in meters
                                // (if 0, distance is not calculated, ie. not used for motion confirmation)
      "motionStopTimeout": 10.0 // timeout to confirm motion stop, in seconds
    },

    "repossessionMode": {
      "enabled": true,          // true - repossession mode is enabled
      "after": 1667598736       // (05.11.2022 00:52:16) UNIX timestamp after which location obtaining is activated
    },

    "bleDevices": {
      "enabled": false,         // true - location obtaining using BLE devices is enabled
      "generic": {              // set of generic devices

      },
      "iBeacon": {              // set of iBeacon devices

      }
    },

    "geofence": {               // geofence zone
      "enabled": false,         // true - geofence is enabled
      "lng": 0.0,               // center longitude, in degrees
      "lat": 0.0,               // center latitude, in degrees
      "radius": 0.0             // radius, in meters
    }
  },

  "connectingPeriod": 180.0,    // how often the tracker connects to network, in seconds

  "readingPeriod": 60.0,        // how often the tracker polls various data, in seconds

  "alerts": {

    "shockDetected" : {         // one-time shock acceleration
      "enabled": true,          // true - alert is enabled
      "threshold": 8.0          // shock acceleration alert threshold, in g
      // IMPORTANT: This value affects the measurement range and accuracy of the accelerometer:
      // the larger the range - the lower the accuracy.
      // This can affect the effectiveness of "movementAccMin".
      // For example: if "threshold" > 4.0 g, then "movementAccMin" should be > 0.1 g
    },

    "temperatureLow": {         // temperature crosses the lower limit (becomes below the threshold)
      "enabled": true,          // true - alert is enabled
      "threshold": 10.0,        // temperature low alert threshold, in Celsius
      "hysteresis": 1.0         // "hysteresis" to avoid alerts "bounce", in Celsius
    },

    "temperatureHigh": {        // temperature crosses the upper limit (becomes above the threshold)
      "enabled": true,          // true - alert is enabled
      "threshold": 25.0,        // temperature high alert threshold, in Celsius
      "hysteresis": 1.0         // "hysteresis" to avoid alerts "bounce", in Celsius
    },

    "batteryLow": {             // battery level crosses the lower limit (becomes below the threshold)
      "enabled": false,         // true - alert is enabled
      "threshold": 12.0         // battery low alert threshold, in %
    },

    "tamperingDetected": {      // Not supported!
      "enabled": false          // true - alert is enabled
    }
  },

  "debug": {                    // debug settings
    "logLevel": "DEBUG"         // logging level on Imp-Device ("ERROR", "INFO", "DEBUG")
  }
}