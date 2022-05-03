# Prog-X Asset Tracker Southbound REST API #

Configuring a tracker from a cloud.

**Version of the configuration format/scheme: 1.0**

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
        "after": <string>       // Timestamp (Unix time - secs since the Epoch) after which location obtaining is activated
      },

      "bleDevices": {         // Bluetooth Low Energy (BLE) devices for location obtaining.
                              // Two types of BLE devices are supported - "generic", "iBeacon".
        "enabled": true/false,  // true - location obtaining using BLE devices is enabled

        "generic": {            // New set of generic devices - fully replaces the previous set of generic devices
          <mac>: {                // Generic device identifier (MAC address). Example: "db9786256c43"
                                    // Device location coordinates.
                                    // "lng" and "lat" should be specified together only.
            "lng": <number>,        // Longitude, in degrees
            "lat": <number>         // Latitude, in degrees
          },
          ... // more generic devices can be specified
        },

        "iBeacon": {            // New set of iBeacon devices - fully replaces the previous set of iBeacon devices
          <uuid>: {               // Group UUID (16 bytes). Example: "74d2515660e6444ca177a96e67ecfc5f"
            <major>: {               // Sub-group identifier, number from 0 to 65535
              <minor>: {                // Device identifier, number from 0 to 65535
                                          // Device location coordinates.
                                          // "lng" and "lat" should be specified together only.
                "lng": <number>,          // Longitude, in degrees
                "lat": <number>           // Latitude, in degrees
              },
              ... // more iBeacon devices with the same sub-group identifier can be specified
            },
            ... // more iBeacon sub-groups can be specified
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

      "tamperingDetected": {    // TBD
        "enabled": true/false     // true - alert is enabled
      }
    },

    "debug": {              // Debug settings
      "logLevel": "INFO"      // Logging level on Imp-Device ("ERROR", "INFO", "DEBUG")
    }
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

Examples of "configuration" and "agentConfiguration" blocks can be found in [Default Configuration](../README.md#default-configuration).

Example of a full reported configuration can found here - ???

## Behavior Description ##

### Location obtaining ###

#### BLE ####

#### geofencing ####

### Motion monitoring ###

#### Motion start ####

#### Motion stop ####

### data and alerts ###

### Configuration selection on the tracker ###
