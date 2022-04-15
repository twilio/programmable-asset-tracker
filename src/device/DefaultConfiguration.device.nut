{
  "updateId": "myDefaultCfg",   // unique Id of the cfg update:
                                //   - must be specified for every cfg update
                                //   - in reported cfg: Id of the last known applied update

  "locationTracking": {         // location obtaining is activated if any of the following occurs:
                                //   1) "alwaysOn" is true
                                //   2) "motionMonitoring" is enabled and the tracker is in motion
                                //   3) "repossessionMode" is enabled and the current timestamp is greater than the specified one

    "locReadingPeriod": 180,      // how often the tracker reads location when location obtaining is activated, in seconds,
                                  // [LOC_READING_SAFEGUARD_MIN..LOC_READING_SAFEGUARD_MAX]

    "alwaysOn": false,            // (Not supported!) true - location obtaining is always activated

    "motionMonitoring": {         // motion start/stop monitoring. When in motion, location obtaining becomes activated
      "enabled": true,              // true - motion monitoring is enabled
                                    // motion start detection settings
                                    // movement acceleration threshold range [movementAccMin..movementAccMax]:
                                      // can be updated together only, movementAccMax >= movementAccMin
      "movementAccMin": 0.2,          // minimum (starting) level, in g, [>0..TBD]
      "movementAccMax": 0.4,          // maximum level, in g, [>0..TBD],
      "movementAccDur": 0.25,       // duration of exceeding movement acceleration threshold, in seconds, [>0..TBD]
      "motionTime": 15.0,           // maximum time to determine motion detection after the initial movement, in seconds,
                                    // [MOTION_TIME_SAFEGUARD_MIN..MOTION_TIME_SAFEGUARD_MAX]
      "motionVelocity": 0.5,        // minimum instantaneous velocity to determine motion detection condition, in meters per second,
                                    // [MOTION_VEL_SAFEGUARD_MIN..MOTION_VEL_SAFEGUARD_MAX]
      "motionDistance": 5.0         // minimum movement distance to determine motion detection condition, in meters,
                                    // [0, MOTION_DIST_SAFEGUARD_MIN..MOTION_DIST_SAFEGUARD_MAX]
                                    // (if 0, distance is not calculated, ie. not used for motion detection)
    },

    "repossessionMode": {         // (Not supported!) location obtaining activation after some date
      "enabled": false,             // true - repossession mode is enabled
      "after": 0                    // UNIX timestamp after which location obtaining is activated, >SOME_RESONABLE_TIMESTAMP
    },

    "bleDevices": {               // Bluetooth Low Enegry (BLE) devices for location obtaining
      "enabled": false,             // true - location obtaining using BLE devices is enabled
      "generic": {                  // new set of generic devices - fully replaces the previous set of generic devices

      },
      "iBeacon": {                  // new set of iBeacon devices - fully replaces the previous set of iBeacon devices

      }
    },

    "geofence": {                 // circle geofence (center, radius) TBD
      "enabled": true,             // true - geofence is enabled
                                    // lng, lat, radius - can be updated together only
      "lng": 0,                     // center longitude, in degrees, [-180..180]
      "lat": 0,                     // center latitude, in degrees, [-90..90]
      "radius": 0                   // radius, in meters, [EARTH_RADIUS..0]
    }
  },

  "connectingPeriod": 60.0,     // how often the tracker connects to network, in seconds,
                                // [CONNECTING_SAFEGUARD_MIN..CONNECTING_SAFEGUARD_MAX]

  "readingPeriod": 20.0,        // how often the tracker polls various data, in seconds,
                                // [READING_SAFEGUARD_MIN..READING_SAFEGUARD_MAX]

  "alerts": {                   // additional (not tracking related) alerts

    "shockDetected" : {           // one-time shock acceleration
      "enabled": true,              // true - alert is enabled
      "threshold": 8.0              // shock acceleration alert threshold, in g,
                                    // [SHOCK_ACC_SAFEGUARD_MIN..SHOCK_ACC_SAFEGUARD_MAX]
    },

    "temperatureLow": {           // temperature crosses the border (becomes below the threshold)
      "enabled": true,              // true - alert is enabled
      "threshold": 10.0,            // temperature low alert threshold, in Celsius
      "hysteresis": 1.0             // "hysteresis" to avoid alerts "bounce", in Celsius, >=0
    },

    "temperatureHigh": {          // temperature crosses the border (becomes above the threshold)
      "enabled": true,              // true - alert is enabled
      "threshold": 25.0,            // temperature high alert threshold, in Celsius
      "hysteresis": 1.0             // "hysteresis" to avoid alerts "bounce", in Celsius, >=0
    },

    "batteryLow": {               // battery level crosses the border (becomes below the threshold)
      "enabled": false,             // true - alert is enabled
      "threshold": 12               // battery low alert threshold, in %, [0..100]
    },

    "tamperingDetected": {        // Not supported!
      "enabled": false              // true - alert is enabled
    }
  }
}
