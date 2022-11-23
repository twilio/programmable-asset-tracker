# Programmable Asset Tracker Southbound REST API #

Configuring a tracker from a cloud.

**Version of the configuration format/scheme: 1.1**

## Introduction ##

The configuration includes three blocks:
- "description" - read-only information returned by the tracker. Does not exist in the configuration update from a cloud.
- "configuration" - the main (Imp-Device) block of the tracker configuration.
- "agentConfiguration" - Imp-Agent block of the tracker configuration.

The tracker always has a full configuration (all fields of the "configuration" and "agentConfiguration" blocks):
- Initially, the full configuration is defined by [Default Configuration](../README.md#default-configuration).
- After that the configuration can be updated via Southbound REST API.
- The updated configuration is saved in non-volatile/flash memory and restored after the tracker application restart.

A cloud can ask the tracker to update the configuration. The update may include all configuration fields or a subset of them.

A cloud can ask the tracker to report the latest known configuration.

Default configuration, configuration updates and reported configuration - all use the same [Configuration JSON Format](#configuration-json-format).

## REST API ##

The tracker application (Imp-Agent part) implements the following REST API:
- Accepts `GET/PATCH https://<tracker_api_url>/cfg` requests. Where:
  - `<tracker_api_url>` - is the Imp-Agent URL. It comprises the base URL `agent.electricimp.com` plus the [agent’s ID](https://developer.electricimp.com/faqs/terminology#agent). Example: `https://agent.electricimp.com/7jiDVu1t_w--`
  - `/cfg` - is an endpoint.
- Supports the basic authentication - `<username>/<password>`. Where:
  - `<username>/<password>` should be set as `CFG_REST_API_USERNAME`/`CFG_REST_API_PASSWORD` [Environment Variables](../README.md#user-defined-environment-variables) in the Imp application.
- Returns HTTP response code `401` if no or invalid authentication details are provided.

### GET /cfg ###

Reports the latest known configuration of the tracker application.

The tracker application (Imp-Agent part) returns:
- HTTP response code `200`
- HTTP message body with the reported configuration in the [Configuration JSON Format](#configuration-json-format):
  - "description" block - always exists,
  - "agentConfiguration" block - always exists,
  - "configuration" block - exists if known. Note, in some cases it can be absent, for example, while the tracker is in the shipment mode.

### PATCH /cfg ###

Requests an update of the tracker application configuration.

The configuration update may include all fields of the "configuration" and "agentConfiguration" blocks, a subset of the fields, or even a one field only. Note, some of the fields can be updated together only, it is specified in the [Configuration JSON Format](#configuration-json-format).

The tracker application (Imp-Agent part):
- Accepts message body with the configuration update in the [Configuration JSON Format](#configuration-json-format).
- Validates the correctness of the configuration update:
  - types of the field values,
  - supported ranges of the field values,
  - fields which should be updated together only, etc.
- Returns HTTP response code `400` if the configuration update is incorrect.
- Returns HTTP response code `200` if the configuration update passes all preliminary checks.
- Immediately applies "agentConfiguration" block of the configuration (if it exist in the configuration update).
- Saves "configuration" block of the configuration (if it exist in the configuration update) as a pending configuration and processes it.

#### Pending Configuration Processing ####

Every "configuration" update has a unique Id specified by a cloud. Note, [Default Configuration](../README.md#default-configuration) has a predefined Id.

Every "configuration" update from a cloud becomes a pending update. It stays pending till it is successfully delivered to the tracker (to the Imp-Device part of the tracker application).

There can be not more than one pending configuration update at a time. A new "configuration" update from a cloud overwrites the current pending update, if any. I.e. the cloud should wait for the previous update is delivered to the tracker and send a new update after that.

If there is a pending update, then the "description" block of the configuration reported by the tracker to a cloud includes the "pendingUpdateId" field - the Id of the current pending update. If there is no such a field, then no pending update is waiting for delivery to the tracker at this moment.

Note, a delivering of the "configuration" update to the tracker (absence of the pending update) does not mean the latest update has been already successfully applied. The update still can fail during applying and/or the tracker becomes offline and its actual configuration is not known yet.

The "configuration" block of the configuration reported by the tracker to a cloud always includes the "updateId" field - the Id of the latest known successfully applied configuration update.

## Configuration JSON Format ##

- All keys and values are case sensitive.
- All fields are optional, if not specified otherwise.
- Most of the fields which can be changed have "safeguards" - supported range and/or list of supported values.
- For more details about some of the settings and other information - see [Behavior Description](#behavior-description).

```
{
  "description": {  // Read-only information returned by the tracker.
                    // Always exist in the configuration reported by the tracker to a cloud.
                    // Does not exist in a configuration update from a cloud to the tracker.

    "trackerId": <string>,        // Unique tracker Id (imp deviceId).
    "cfgSchemeVersion": <string>, // Supported configuration format/scheme version: "<major>.<minor>"
    "cfgTimestamp": <number>,     // Timestamp (Unix time - secs since the Epoch) when the latest cfg update has been applied.
                                  // Does not exist if configuration from the tracker is not known at this moment,
                                  //   "configuration" block does not exist in this case either.
    "pendingUpdateId": <string>   // Id of the pending cfg update. Does not exist if there is no pending cfg at this moment.
  },

  "configuration": {    // The main (Imp-Device) block of the tracker configuration.
                        // In a configuration update: may include all fields, subset of the fields, may be absent.
                        // In the reported configuration: may not exist if it is not known at this moment,
                        //   but if it exists then it contains all fields.

    "updateId": <string>,   // Unique Id of a configuration update. Mandatory.
                            // In a configuration update: a cloud should specify a unique Id for every cfg update.
                            // In the reported configuration: Id of the latest known successfully applied configuration update.

    "locationTracking": {      // Location obtaining is activated if any of the following occurs:
                               //   1) "alwaysOn" is true
                               //   2) "motionMonitoring" is enabled and the tracker is in motion
                               //   3) "repossessionMode" is enabled and the current timestamp is greater than the specified one

      "locReadingPeriod": <number>, // How often the tracker reads location when location obtaining is activated, in seconds

      "alwaysOn": true/false,       // true - location obtaining is always activated

      "motionMonitoring": {         // Motion start/stop monitoring. When in motion, location obtaining becomes activated.
        "enabled": true/false,        // true - motion monitoring is enabled

                                      // Motion start detection settings:
                                      // Movement acceleration threshold range - ["movementAccMin".."movementAccMax"]
                                      // Should be updated together only, "movementAccMax" >= "movementAccMin"
        "movementAccMin": <number>,   // minimum (starting) level, in g
        "movementAccMax": <number>,   // maximum level, in g
        "movementAccDur": <number>,   // Duration of exceeding the movement acceleration threshold, in seconds
        "motionTime": <number>,       // Maximum time to confirm motion detection after the initial movement, in seconds
        "motionVelocity": <number>,   // Minimum instantaneous velocity to confirm motion detection, in meters per second
        "motionDistance": <number>,   // Minimum movement distance to confirm motion detection, in meters
                                      //   If 0, the distance is not calculated, ie. not used for motion confirmation.

                                      // Motion stop detection settings:
        "motionStopTimeout": <number> // Time without movement for motion stop confirmation, in seconds
      },

      "repossessionMode": {   // Location obtaining activation after the specified date
        "enabled": true/false,  // true - repossession mode is enabled
        "after": <number>       // Timestamp (Unix time - secs since the Epoch) after which location obtaining is activated
      },

      "bleDevices": {         // Bluetooth Low Energy (BLE) devices for location obtaining.
                              // Two types of BLE devices are supported - "generic", "iBeacon".
        "enabled": true/false,  // true - location obtaining using BLE devices is enabled

        "generic": {            // New set of generic devices - fully replaces the previous set of generic devices
          <mac>: {                // Generic device identifier (MAC address). Must be lowercase. Example: "db9786256c43"
                                    // Device location coordinates.
                                    // "lng" and "lat" should be specified together only.
            "lng": <number>,        // Longitude, in degrees
            "lat": <number>         // Latitude, in degrees
          },
          ... // more generic devices can be specified
        },

        "iBeacon": {            // New set of iBeacon devices - fully replaces the previous set of iBeacon devices
          <uuid>: {               // Group UUID (16 bytes). Must be lowercase. Example: "74d2515660e6444ca177a96e67ecfc5f"
            <major>: {               // Sub-group identifier, number from 0 to 65535
              <minor>: {                // Device identifier, number from 0 to 65535
                                          // Device location coordinates.
                                          // "lng" and "lat" should be specified together only.
                "lng": <number>,          // Longitude, in degrees
                "lat": <number>           // Latitude, in degrees
              },
              ... // more iBeacon devices with the same sub-group identifier can be specified
            },
            ... // more iBeacon sub-groups with the same group UUID can be specified
          },
          ... // more iBeacon groups can be specified
        }
      },

      "geofence": {           // Circle geofence zone.
                              // Not more than one zone can be configured at a time.
        "enabled": true/false,  // true - geofence zone is enabled
                                // Zone center location coordinates and radius.
                                // "lng", "lat" and "radius" should be specified together only.
        "lng": <number>,        // Center longitude, in degrees
        "lat": <number>,        // Center latitude, in degrees
        "radius": <number>      // Radius, in meters
      }
    },

    "connectingPeriod": <number>, // How often the tracker connects to network, in seconds

    "readingPeriod": <number>,    // How often the tracker polls various data, in seconds

    "alerts": {               // Additional (not tracking related) alerts

      "shockDetected" : {       // One-time shock acceleration
        "enabled": true/false,    // true - alert is enabled
        "threshold": <number>     // Shock acceleration alert threshold, in g
        // IMPORTANT: This value affects the measurement range and accuracy of the accelerometer:
        // the larger the range - the lower the accuracy.
        // This can affect the effectiveness of "movementAccMin".
        // For example: if "threshold" > 4.0 g, then "movementAccMin" should be > 0.1 g
      },

      "temperatureLow": {       // Temperature crosses the lower limit (becomes below the threshold)
        "enabled": true/false,    // true - alert is enabled
        "threshold": <number>,    // Temperature low alert threshold, in Celsius
        "hysteresis": <number>    // Hysteresis to avoid alerts "bounce", in Celsius
      },

      "temperatureHigh": {      // Temperature crosses the upper limit (becomes above the threshold)
        "enabled": true/false,    // true - alert is enabled
        "threshold": <number>,    // Temperature high alert threshold, in Celsius
        "hysteresis": <number>    // Hysteresis to avoid alerts "bounce", in Celsius
      },

      "batteryLow": {           // Battery level crosses the lower limit (becomes below the threshold)
        "enabled": true/false,    // true - alert is enabled
        "threshold": <number>     // Battery low alert threshold, in %
      },

      "tamperingDetected": {    // Tampering is detected (light is detected by photoresistor)
        "enabled": true/false,    // true - alert is enabled
        "pollingPeriod": <number> // Photoresistor polling period, in seconds
      }
    },

    "debug": {              // Debug settings
      "logLevel": "INFO"      // Logging level on Imp-Device ("ERROR", "INFO", "DEBUG")
    }
  },

  "simUpdate": {          // SIM OTA update
    "enabled": true/false,  // true - force SIM OTA update every time Imp-Device is connected
    "duration": <number>    // Duration of connection retention (when SIM OTA update is forced), in seconds
  },

  "agentConfiguration": { // Imp-Agent block of the tracker configuration.
                          // In a configuration update: may include all fields, subset of the fields, may be absent.
                          // In the reported configuration: contains all fields.

    "debug": {              // Debug settings
      "logLevel": "INFO"      // Logging level on Imp-Agent ("ERROR", "INFO", "DEBUG")
    }
  }
}
```

## Configuration Examples ##

Examples of the "configuration" and "agentConfiguration" blocks can be found in [Default Configuration](../README.md#default-configuration).

Example of a full reported configuration:
```
{
    "description": {
        "trackerId": "600a0002d7026715",
        "cfgTimestamp": 1651659656,
        "cfgSchemeVersion": "1.1"
    },
    "configuration": {
        "updateId": "61",
        "locationTracking": {
            "locReadingPeriod": 30,
            "alwaysOn": true,
            "motionMonitoring": {
                "enabled": true,
                "movementAccMin": 0.15000001,
                "movementAccMax": 0.30000001,
                "movementAccDur": 0.25,
                "motionTime": 5,
                "motionDistance": 1,
                "motionVelocity": 0.25,
                "motionStopTimeout": 10
            },
            "repossessionMode": {
                "enabled": false,
                "after": 1651655116
            },
            "bleDevices": {
                "enabled": true,
                "generic": {},
                "iBeacon": {
                    "0112233445566778899aabbccddeeff0": {
                        "1800": {
                            "1286": {
                                "lng": 16.32,
                                "lat": 64.255997
                            }
                        }
                    }
                }
            },
            "geofence": {
                "enabled": true,
                "lat": 0,
                "lng": 0,
                "radius": 0
            }
        },
        "connectingPeriod": 60,
        "readingPeriod": 20
        "alerts": {
            "batteryLow": {
                "enabled": true,
                "threshold": 16
            },
            "shockDetected": {
                "enabled": true,
                "threshold": 3
            },
            "tamperingDetected": {
                "enabled": true,
                "pollingPeriod": 1
            },
            "temperatureHigh": {
                "enabled": true,
                "hysteresis": 1,
                "threshold": 25
            },
            "temperatureLow": {
                "enabled": true,
                "hysteresis": 1,
                "threshold": 20
            }
        },
        "debug": {
            "logLevel": "DEBUG"
        }
    },
    "simUpdate": {
        "enabled": false,
        "duration": 60
    },
    "agentConfiguration": {
        "debug": {
            "logLevel": "DEBUG"
        }
    }
}
```

Example of a curl command (it updates the log level on Imp-Agent):
```
curl -u test:test -k --data '{"agentConfiguration":{"debug":{"logLevel":"DEBUG"}}}' -H "content-type: application/json" -X PATCH https://agent.electricimp.com/LPoC4xOL8ESr_/cfg
```

## Behavior Description ##

### Location Tracking ###

Location is determined:
- once after every restart of the tracker application,
- periodically, if any of the following conditions has occurred:
  - "alwaysOn" is true,
  - "motionMonitoring" is enabled and the tracker is in motion,
  - "repossessionMode" is enabled and the current timestamp is greater than the specified timestamp ("after").

Period of location determination is specified by "locReadingPeriod".

The latest determined location is saved in non-volatile memory and is restored after every restart of the tracker application.

The application tries to determine a location using different ways in the following order:
1. By nearby BLE devices, if "bleDevices" is enabled and a list of BLE devices with their coordinates is specified. Currently, two types of BLE devices are supported: generic devices specified by MAC address and iBeacon devices.
1. By GNSS fix (u-blox NEO-M8N GNSS). U-blox AssistNow data, if available, is used to speed up GNSS fix. GNSS fix is accepted as the determined location if a location with accuracy not more than 50 meters is returned by the GNSS module during not more than 55 seconds. 
1. By nearby WiFi networks information. Google Maps Geolocation API is used.
1. By nearby cellular towers information. Google Maps Geolocation API is used.

### Geofencing ###

When "geofence" is enabled, every time after a new location is determined the application checks if the tracker enters or exits the geofence zone.

Two circles are used for that:
- geofence circle - a circle with the radius defined by the geofence "radius" setting in the configuration,
- location circle - a circle with the radius equal to the accuracy of the latest known location.

"geofenceEntered" alert is generated when the location circle becomes fully inside the geofence circle.

"geofenceExited" alert is generated when the location circle becomes fully outside the geofence circle.

### Motion Monitoring ###

When "motionMonitoring" is enabled, the tracker application uses data from accelerometer and location tracking to determine if the tracker is in motion or not.

#### Motion Start ####

Motion start detection consists of the two steps:
1. initial movement detection,
1. motion start confirmation.

Accelerometer is switched on and is used during the both steps. Location tracking is not used for motion start detection.

##### Initial Movement Detection #####

Accelerometer is configured to detect a movement.

"movementAccMin" and "movementAccMax" specify the range for movement acceleration threshold:
- Initially, the acceleration threshold is set to "movementAccMin".
- If the movement is detected but after that the motion start is not confirmed, then the acceleration threshold is increased by 0.1 g.
- This may happen several times, but the maximum value set for the acceleration threshold is "movementAccMax".
- Every time when the motion start is confirmed, the acceleration threshold is reset back to "movementAccMin".

"movementAccDur" specifies the duration of exceeding the movement acceleration threshold.

If accelerometer detects a movement, the algorithm goes to the second step - motion start confirmation.

##### Motion Start Confirmation #####

Accelerometer is configured to provide data for velocity and distance calculations.

"motionTime" specifies the maximum time to confirm the motion start after the initial movement is detected.

There are two independent conditions to confirm the motion start:
- Instantaneous velocity reaches/exceeds "motionVelocity" at least once during "motionTime" and is not zero at the end of "motionTime". In this case the motion start is confirmed right after "motionTime".
- Optional (is disabled if "motionDistance" is set to 0). Total motion distance after the initial movement reaches "motionDistance" before "motionTime". In this case the motion start is confirmed immediately, without waiting for "motionTime".

Example:
```
"motionTime": 15.0,
"motionVelocity": 0.5,
"motionDistance": 5.0
Motion start will be confirmed if:
- Either instantaneous velocity 0.5 m/sec (or more) is detected at least once and it is still not zero after 15 secs.
- Or total motion distance reaches 5 meters anytime before 15 secs. 
```

If the motion start is not confirmed by any of the conditions after "motionTime", then the algorithm returns to the first step - initial movement detection.

If the motion start is confirmed by any of the conditions:
- "motionStarted" alert is generated,
- accelerometer is switched off,
- periodic location tracking is activated (if it is not already active by other configuration settings),
- the algorithm starts detection the motion stop.

#### Motion Stop ####

Motion stop detection consists of the two steps:
1. motion stop assumption checking,
1. motion stop confirmation.

##### Motion Stop Assumption Checking #####

Location is determined periodically, with "locReadingPeriod".

When a new location is determined it is compared with the previous one. If the both locations are identical (taking into account location accuracy), then the motion stop assumption occurs. Note, the motion stop assumption occurs also when a location can not be determined during two "locReadingPeriod" in a raw.

If the motion stop assumption occurs:
- periodic location tracking is deactivated (it can still continue to be active by other configuration settings),
- accelerometer is switched on and configured like for motion start detection, it is going to be used to check if the motion is really stopped or not,
- the algorithm goes to the second step - motion stop confirmation.

##### Motion Stop Confirmation #####

"motionStopTimeout" - timeout after the motion stop assumption to confirm the motion stop.

If during "motionStopTimeout" a motion start is detected (ie. the tracker is still in motion):
- periodic location tracking is reactivated (if it is not already active by other configuration settings),
- the algorithm returns to the first step - motion stop assumption checking.

If during "motionStopTimeout" a motion start is not detected (ie. the motion stop is confirmed):
- "motionStopped" alert is generated,
- the algorithm continues with the motion start detection.

### Data And Alerts ###

Some data is obtained "by event" and corresponding alerts are checked/generated immediately.

Other data is obtained "by polling" - periodically, with "readingPeriod". And corresponding alerts are checked/generated with the same period.

If no alerts occur, the data is saved in SPI flash and sent to a cloud periodically, with "connectingPeriod".

If an alert occurs, the new and previously unsent data are sent immediately.

### SIM OTA Update ###

Imp-Device does not detect neither when SIM update is needed, nor when SIM update is completed. SIM update procedure should be controlled using the configuration settings in the "simUpdate" section:
- To start SIM update procedure: "enabled" should be set to true.
- When SIM is updated: 'enabled" should be set back to false.

SIM update should not be left enabled when it is not needed due to the increased power consumption.

### Configuration Deployment Algorithm ###

After every restart of the tracker application (Imp-Device part):
- If it is a new build of the application and "ERASE_MEMORY" builder-variable is enabled, then the saved configuration (if any) is deleted from SPI flash.
- If a configuration exists in SPI flash, then it is being deployed:
  - If the configuration deployment is successful, then it is reported as the actual configuration and the tracking starts working.
  - If the configuration deployment is not successful, then the saved configuration is deleted from SPI flash and the tracker is restarted.
- If there is no configuration saved in SPI flash, then the default configuration (should exist with every build of the application) is being deployed:
  - If the configuration deployment is successful, then it is reported as the actual configuration and the tracking starts working.
  - If the configuration deployment is not successful, then the application goes to Emergency Mode.

After a configuration update, which can come in runtime from a cloud, is successfully applied, the full new configuration is saved in SPI flash and is reported as the actual configuration.

The tracking is not stopped during the configuration update is being applied. Only components which are affected by the update may be temporary stopped / restarted.

