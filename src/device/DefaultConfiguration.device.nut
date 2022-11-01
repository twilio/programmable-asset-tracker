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

{
  "updateId": "myDefaultCfg",

  "locationTracking": {

    "locReadingPeriod": 180.0   // how often the tracker reads location when location obtaining is activated, in seconds

    "alwaysOn": false,          // true - location obtaining is always activated

    "motionMonitoring": {
      "enabled": true,          // true - motion monitoring is enabled
      "movementAccMin": 0.15,   // minimum (starting) acceleration threshold for movement detection, in g
      "movementAccMax": 0.15,   // maximum  acceleration threshold for movement detection, in g
      "movementAccDur": 0.01,   // duration of exceeding movement acceleration threshold, in seconds
      "motionTime": 8.0,        // maximum time to confirm motion detection after the initial movement, in seconds
      "motionVelocity": 0.1,    // minimum instantaneous velocity to confirm motion detection condition, in meters per second
      "motionDistance": 2.0,    // minimum movement distance to determine motion detection condition, in meters
                                // (if 0, distance is not calculated, ie. not used for motion confirmation)
      "motionStopTimeout": 30.0 // timeout to confirm motion stop, in seconds
    },

    "repossessionMode": {
      "enabled": false,         // true - repossession mode is enabled
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
      "threshold": 4.0          // shock acceleration alert threshold, in g
      // IMPORTANT: This value affects the measurement range and accuracy of the accelerometer:
      // the larger the range - the lower the accuracy.
      // This can affect the effectiveness of "movementAccMin".
      // For example: if "threshold" > 4.0 g, then "movementAccMin" should be > 0.1 g
    },

    "temperatureLow": {         // temperature crosses the lower limit (becomes below the threshold)
      "enabled": true,          // true - alert is enabled
      "threshold": 16.0,        // temperature low alert threshold, in Celsius
      "hysteresis": 1.0         // "hysteresis" to avoid alerts "bounce", in Celsius
    },

    "temperatureHigh": {        // temperature crosses the upper limit (becomes above the threshold)
      "enabled": true,          // true - alert is enabled
      "threshold": 25.0,        // temperature high alert threshold, in Celsius
      "hysteresis": 1.0         // "hysteresis" to avoid alerts "bounce", in Celsius
    },

    "batteryLow": {             // battery level crosses the lower limit (becomes below the threshold)
      "enabled": true,          // true - alert is enabled
      "threshold": 30.0         // battery low alert threshold, in %
    },

    "tamperingDetected": {      // tampering detected (light was detected by the photoresistor)
      "enabled": false,         // true - alert is enabled
      "pollingPeriod": 1.0      // photoresistor polling period, in seconds
    }
  },

  "simUpdate": {                // SIM OTA update
    "enabled": false,           // true - SIM OTA update is enabled. This will force SIM OTA update every
                                // time the device connects to the Internet. And will keep the device connected
                                // for the specified time to let the update happen
    "duration": 60              // duration of connection retention (when SIM OTA update is forced), in seconds
  },

  "debug": {                    // debug settings
    "logLevel": "INFO"          // logging level on Imp-Device ("ERROR", "INFO", "DEBUG")
  }
}
