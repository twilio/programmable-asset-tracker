# Prog-X Asset Tracker #

**Version of the Application: 1.2.0 (POC)**

An application in Squirrel language for [Electric Imp platform](https://www.electricimp.com/platform) that implements asset tracking functionality.

The requirements: [./docs/Requirements - Prog-X Asset Tracker - external-GPx.pdf](./docs/Requirements%20-%20Prog-X%20Asset%20Tracker%20-%20external-GPx.pdf)

This version (Proof-Of-Concept) supports:
- Target board: [imp006 Breakout Board](https://developer.electricimp.com/hardware/resources/reference-designs/imp006breakout)
- Communication with the Internet (between Imp-Device and Imp-Agent) via cellular network.
- Application configuration is hardcoded in the source file.
- Motion start detection using Accelerometer.
- Periodic Location tracking when the asset is in motion.
- Motion stop detection using Location tracking (+ Accelerometer for confirmation).
- Default configuration settings intended for manual testing of motion ("walking pattern").
- Location tracking by:
  - GNSS fix (BG96 GNSS) (+ BG96 Assist data)
  - Cellular towers information (+ Google Maps Geolocation API)
- Periodic reading and reporting of:
  - Temperature
- Alerts determination and immediate reporting for:
  - Temperature High
  - Temperature Low
  - Shock Detected
  - Motion Started
  - Motion Stopped
- Staying offline most of time. Connect to the Internet (from Imp-device to Imp-Agent) when required only. Internet connection is used for:
  - Data/alerts sending
  - GNSS Assist data obtaining
  - Location obtaining by cellular towers information
- If no/bad cellular network, saving messages in the flash and re-sending them later.
- Sending data/alerts from Imp-Agent to a cloud with the predefined REST API.
- Emergency (recovery) mode.
- UART logging.
- LED indication of the application behavior.
- The cloud REST API simple emulation on another Imp.

## Source Code ##

Shared sources: [./src/shared](./src/shared)

Imp-Agent sources: [./src/agent](./src/agent)

Imp-Device sources: [./src/device](./src/device)

Preprocessed files: [./build](./build)

## Setup ##

### Hardcoded Configuration ###

Configuration constants: [./src/device/Configuration.device.nut](./src/device/Configuration.device.nut)

### Builder Variables ###

Should be passed to [Builder](https://github.com/electricimp/Builder/):
- either using `-D<variable name> <variable value>` option,
- or using `--use-directives <path_to_json_file>` option, where the json file contains the variables with the values.

Variables:
- `LOGGER_LEVEL` - Logging level ("ERROR", "INFO", "DEBUG") on Imp-Agent/Device after the Imp firmware is deployed. Optional. Default: **"INFO"**
- `UART_LOGGING` - Enable/disable [UART logging](#uart-logging) on Imp-Device. Optional. Default: **enabled**
- `LED_INDICATION` - Enable/disable [LED indication](#led-indication) of events. Optional. Default: **enabled**

### User-Defined Environment Variables ###

Are used for sensitive settings, eg. credentials.

Should be passed to [impcentral Device Group Environment Variables](https://developer.electricimp.com/tools/impcentral/environmentvariables#user-defined-environment-variables) in JSON format

Variables:
- `CLOUD_REST_API_URL` - Cloud REST API URL. Mandatory. Has no default.
- `CLOUD_REST_API_USERNAME` - Username to access the cloud REST API. Mandatory. Has no default.
- `CLOUD_REST_API_PASSWORD` - Password to access the cloud REST API. Mandatory. Has no default.
- `GOOGLE_MAPS_API_KEY` - API Key for Google Maps Platform. Required by [Google Maps Geolocation API](https://developers.google.com/maps/documentation/geolocation/overview) to determine the location by cell towers info or by WiFi networks. See [here](https://developers.google.com/maps/documentation/geolocation/get-api-key) how to obtain the Key.

Example of JSON with environment variables (when Cloud REST API is [emulated on another Imp](#simple-cloud-emulation)):
```
{
  "CLOUD_REST_API_URL": "https://agent.electricimp.com/7jiDVu1t_w-1", // not a real url
  "CLOUD_REST_API_USERNAME": "test",
  "CLOUD_REST_API_PASSWORD": "test",
  "GOOGLE_MAPS_API_KEY": "AIzaSyDJQV2m_qNMjdw5snP6qPjdtoMRau-ger8" // not a real key
}
```

## Build And Run ##

- If no need to change the default values of [Configuration Constants](#hardcoded-configuration) and [Builder Variables](#builder-variables), take already preprocessed files from the [./build](./build) folder.
- Otherwise: 
  - Change [Configuration Constants](#hardcoded-configuration), if needed.
  - Specify [Builder Variables](#builder-variables), if needed.
  - Run [Builder](https://github.com/electricimp/Builder/) for [./src/agent/Main.agent.nut](./src/agent/Main.agent.nut) file to get Imp-Agent preprocessed file.
  - Run [Builder](https://github.com/electricimp/Builder/) for [./src/device/Main.device.nut](./src/device/Main.device.nut) file to get Imp-Device preprocessed file.
- Specify mandatory [Environment Variables](#user-defined-environment-variables) in the impcentral Device Group where you plan to run the application.
- Create and build a new deployment in the Device Group and restart Imp.
- Control the application behavior using logs in the impcentral and/or via [UART logging](#uart-logging) (if enabled), and using [LED indication](#led-indication) (if enabled).

## Simple Cloud Integration ##

To get data messages from the Asset Tracker application running on Imp, a cloud should implement the following REST API:
- Accept `POST https://<cloud_api_url>/data` requests. Where:
  - `<cloud_api_url>` will be set as `CLOUD_REST_API_URL` [Environment Variable](#user-defined-environment-variables) in the Imp application,
  - `/data` - is an endpoint.
- Support the basic authentication - `<username>/<password>`. Where:
  - `<username>/<password>` will be set as `CLOUD_REST_API_USERNAME`/`CLOUD_REST_API_PASSWORD` [Environment Variables](#user-defined-environment-variables) in the Imp application.
- Accept message body in [JSON format](#data-message-json).
- Return HTTP response code `200` when a message is accepted/received. The Imp application interpreters any other codes as error.

### Data Message JSON ###

All fields are mandatory, if not specified otherwise.

```
{
   "trackerId": <string>,    // Unique Id of the tracker (Imp deviceId)
   "timestamp": <number>,    // Timestamp when the data was read (Unix time - secs since the Epoch)
   "status": {
     "inMotion": <boolean>   // true - the asset is in motion now; false - the asset is not in motion
   },
   "location": {             // Last known location
     "timestamp": <number>,  // Timestamp when this location was determined (Unix time - secs since the Epoch)
     "type": <string>,       // Type of location determination: "gnss", "cell", "wifi", "ble"
     "accuracy": 3,          // Location accuracy, in meters
     "lng": <number>,        // Longitude
     "lat": <number>         // Latitude
   },
   "sensors": {
     "temperature": <number> // Current temperature, in Celsius
   },
   "alerts": [ <array_of_strings> ]    // Alerts. Optional. Can be missed or empty if no alerts.
   // Possible values: "temperatureHigh", "temperatureLow", "shockDetected", "motionStarted", "motionStopped"
}
```

Example:
```
{
   "trackerId": "c0010c2a69f088a4",
   "timestamp": 1617900077,
   "status": {
     "inMotion": true
   },
   "location": {
     "timestamp": 1617900070,
     "type": "gnss",
     "accuracy": 3,
     "lng": 30.571465,
     "lat": 59.749069
   },
   "sensors": {
     "temperature": 42.191177
   },
   "alerts": [
     "temperatureHigh",
     "shockDetected"
   ]
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
- [Setup](#setup) the asset tracker application according to the emulator REST API URL/username/password and [run](#build-and-run) the application.
- Check the emulator and the application logs.

## Debug Features ##

### UART Logging ###

When enabled by the [Builder variable](#builder-variables) Imp-Device outputs logs via UART, additionally to the standard output to the impcentral. This is helpful for testing and debugging when Imp-Device is offline.

UART parameters:
- Port: **uartXEFGH**
- Baud rate: **115200**
- Word size: **8 bits**
- Parity: **none**
- Stop bits: **1**
- No CTS/RTS

### LED Indication ###

When enabled by the [Builder variable](#builder-variables) Imp-Device indicates different events using on-board LEDs. This is helpful for testing and debugging, especially when Imp-Device is offline.

There are two LEDs:
- **BlinkUp LED**
  - When the indication is [enabled](#builder-variables), the BlinkUp LED indicates when Imp-Device is online.
  - When the indication is disabled, the BlinkUp LED is active only at the application startup. See the BlinkUp codes [here](https://developer.electricimp.com/troubleshooting/blinkup).
- **User LED** (multi-color)
  - When the indication is [enabled](#builder-variables), the User LED blinks by different colors when the following events occur:
    - New message generated: **green**
    - Shock detected alert: **red**
    - Motion started alert: **white**
    - Motion stopped alert: **cyan**
    - Temperature is low alert: **blue**
    - Temperature is high alert: **yellow**
  - When the indication is disabled, the User LED is not in use.
