# Prog-X Asset Tracker Northbound REST API #

Sending data from the tracker to a cloud.

To get data messages from the Asset Tracker application running on Imp, a cloud (tracking portal) should implement the following REST API:
- Accept `POST https://<cloud_api_url>/data` requests. Where:
  - `<cloud_api_url>` will be set as `CLOUD_REST_API_URL` [Environment Variable](../README.md#user-defined-environment-variables) in the Imp application,
  - `/data` - is an endpoint.
- Support the basic authentication - `<username>/<password>`. Where:
  - `<username>/<password>` should be set as `CLOUD_REST_API_USERNAME`/`CLOUD_REST_API_PASSWORD` [Environment Variables](../README.md#user-defined-environment-variables) in the Imp application.
- Accept message body in [JSON format](#data-message-json).
- Return HTTP response code `200` when a message is accepted/received. The Imp application interpreters any other codes as error.

## Data Message JSON ##

All fields are mandatory, if not specified otherwise.

```
{
   "trackerId": <string>,    // Unique Id of the tracker (Imp deviceId)
   "timestamp": <number>,    // Timestamp when the data was read (Unix time - secs since the Epoch)

   "status": {
     "inMotion": true/false,    // true - the asset is in motion now; false - the asset is not in motion.
                                // Optional. Absent if motion tracking is not enabled in configuration.
     "inGeofence": true/false,  // true - the asset is inside geofence zone now; false - the asset is outside geofence zone.
                                // Optional. Absent if geofencing is not enabled in configuration
                                // or it is not yet determined if the tracker is inside or outside geofence zone.
     "repossession": true/false // true - the asset is in repossession mode now;
                                // false - the asset is not in repossession mode.
                                // Optional. Absent if repossession mode is not enabled in configuration.
   },

   "location": {             // Last known location
     "timestamp": <number>,  // Timestamp when this location was determined (Unix time - secs since the Epoch)
     "type": <string>,       // Type of location determination: "ble", "gnss", "wifi+cell", "wifi", "cell"
     "accuracy": <number>,   // Location accuracy, in meters
     "lng": <number>,        // Longitude
     "lat": <number>         // Latitude
   },

   "sensors": {
     "temperature": <number>,  // Current temperature, in Celsius
     "batteryLevel": <number>  // Current battery level, in %
   },

   "alerts": [ <array_of_strings> ],    // Alerts. Optional. Can be missed or empty if no alerts.
   // Possible values:
   //    "temperatureHigh", "temperatureLow", "shockDetected", "batteryLow", "tamperingDetected",
   //    "motionStarted", "motionStopped", "geofenceEntered", "geofenceExited", "repossessionActivated"

   "cellInfo": {    // Cellular information. Optional. Can be missed or empty if no new information available.
     "timestamp": <number>,     // Timestamp when this information was obtained (Unix time - secs since the Epoch)
     "mode": <string>,          // Service mode: "NOSERVICE", "GSM", "eMTC", "NBIoT"
     "mcc": <string>,           // 3-chars Mobile Country Code
     "mnc": <string>,           // 3-chars Mobile Network Code
     "signalStrength": <number> // Received Signal Strength Indicator
   },

   "gnssInfo": {    // GNSS information. Optional. Can be missed or empty if no new information available.
     "timestamp": <number>,     // Timestamp when this information was obtained (Unix time - secs since the Epoch)
     "satellitesUsed": <number> // Number of satellites used to determine GNSS location
   }
}
```

Example:
```
{
   "trackerId": "c0010c2a69f088a4",
   "timestamp": 1617900077,
   "status": {
     "inMotion": true,
     "repossession": false
   },
   "location": {
     "timestamp": 1617900070,
     "type": "gnss",
     "accuracy": 3,
     "lng": 30.571465,
     "lat": 59.749069
   },
   "sensors": {
     "batteryLevel": 100,
     "temperature": 42.191177
   },
   "alerts": [
     "temperatureHigh",
     "shockDetected"
   ],
   "cellInfo": {
     "timestamp": 1617900010,
     "mode": "eMTC",
     "mcc": "310",
     "mnc": "410",
     "signalStrength": -41
   },
   "gnssInfo": {
     "timestamp": 1617900070
     "satellitesUsed": 5
   }
}
```

### Simple Cloud Emulation ###

Cloud REST API is emulated by an application in Squirrel language which can be run on another Imp device.

How to run the emulator:
- Use any Imp model. Only Imp-Agent is utilized.
- Determine its URL. It comprises the base URL `agent.electricimp.com` plus the [agent’s ID](https://developer.electricimp.com/faqs/terminology#agent). Example: `https://agent.electricimp.com/7jiDVu1t_w--`
- Take the emulator file: [./tests/CloudRestApiEmulator.agent.nut](./tests/CloudRestApiEmulator.agent.nut)
- Set `CLOUD_REST_API_USERNAME` and `CLOUD_REST_API_PASSWORD` constants inside this file. For example to "test"/"test".
- Upload, build and run this file on the Imp which is used for emulation. No [Builder](https://github.com/electricimp/Builder/) is required. Imp-Device code can be empty.
- [Setup](../README.md#setup) the asset tracker application according to the emulator REST API URL/username/password and [run](../README.md#build-and-run) the application.
- Check the emulator and the application logs.
