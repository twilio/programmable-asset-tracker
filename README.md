# Programmable Asset Tracker Application #

**Version of the Application: 3.1.2**

An application in Squirrel language for [Electric Imp platform](https://www.electricimp.com/platform) that implements Programmable Asset Tracker (PAT) functionality.

This version supports:
- Target hardware: [PAT target board schematics](./docs/vdf-nt16e_mb_s11_220228.pdf)
- Communication with the Internet (between Imp-Device and Imp-Agent) via cellular network.
- Default configuration of the asset tracker application is provided as a Device Group environment variable.
- The configuration can be updated in runtime using the [Southbound REST API](./docs/southbound-api.md)
- Motion start detection using Accelerometer.
- Motion stop detection using Location tracking (+ Accelerometer for confirmation).
- Periodic Location tracking by:
  - Nearby BLE devices (+ BLE devices location specified in the configuration). BLE devices with [iBeacon Technology](https://developer.apple.com/ibeacon/) are supported. Found BLE device with the strongest signal (based on RSSI) is used.
  - GNSS fix (u-blox NEO-M8N GNSS) (+ U-blox AssistNow data)
  - Nearby WiFi networks information (+ Google Maps Geolocation API)
  - Nearby cellular towers information (+ Google Maps Geolocation API)
- Repossession (theft) mode (location reporting after a configured date)
- Geofencing:
  - One circle geofence zone configured by the center location and the radius
- Periodic reading and reporting of:
  - Temperature
  - Battery status
  - Cellular and GNSS auxiliary information
- Alerts determination and immediate reporting for:
  - Temperature High
  - Temperature Low
  - Shock Detected
  - Motion Started
  - Motion Stopped
  - Geofence Entered
  - Geofence Exited
  - Battery Low
  - Repossession Mode Activated
  - Tampering Detected
- Power management: switching hardware components off when not used
- Staying offline most of time. Connect to the Internet (from Imp-device to Imp-Agent) when required only. Internet connection is used for:
  - Data/alerts sending
  - GNSS Assist data obtaining
  - Location obtaining by cellular towers and WiFi networks information
  - Reporting the actual device configuration
- If no/bad cellular network, saving messages in the flash and re-sending them later.
- Sending data/alerts from Imp-Agent to a cloud with the predefined [Northbound REST API](./docs/northbound-api.md)
- Emergency (recovery) mode.
- UART logging.
- LED indication of the application behavior.
- Device Evaluation UI on Imp-Agent.
- SIM OTA update initiation via the [Southbound REST API](./docs/southbound-api.md)
- Shipping mode - the application sleeps till the "tamper detection patch" is removed.
- The cloud [Northbound REST API](./docs/northbound-api.md) simple emulation on another Imp.

## Source Code ##

Shared sources: [./src/shared](./src/shared)

Imp-Agent sources: [./src/agent](./src/agent)

Imp-Device sources: [./src/device](./src/device)

Preprocessed files: [./build](./build)

## Setup ##

### Builder Variables ###

Should be passed to [Builder](https://github.com/electricimp/Builder/):
- either using `-D<variable name> <variable value>` option,
- or using `--use-directives <path_to_json_file>` option, where the json file contains the variables with the values.

Variables:
- `ERASE_MEMORY` - Enable (`1`) / disable (`0`) erasing persistent memory used by the application, once after the new application build is deployed. Optional. Default: **disabled**. It can be used, for example, to delete the application configuration previously saved in the flash. **Note:** Only SPI flash of the Imp-Device is erased by this feature.
- `LOGGER_LEVEL` - Set logging level ("ERROR", "INFO", "DEBUG") on Imp-Agent/Device which works after the application restart till the application configuration is applied. Optional. Default: **"INFO"**. Note, when the application configuration is applied, the logging level is set according to the configuration. The logging level can be changed in runtime by updating the configuration.
- `UART_LOGGING` - Enable (`1`) / disable (`0`) [UART logging](#uart-logging) on Imp-Device. Optional. Default: **enabled**
- `LED_INDICATION` - Enable (`1`) / disable (`0`) [LED indication](#led-indication) of events. Optional. Default: **enabled**
- `WEB_UI` - Enable (`1`) / disable (`0`) [Device Evaluation UI](#device-evaluation-ui) on Imp-Agent. Optional. Default: **enabled**

### Default Configuration ###

For the configuration description see the [Southbound REST API](./docs/southbound-api.md)

Default Configuration is specified as a value of the `DEFAULT_CFG` [Environment Variable](#user-defined-environment-variables).

This value must be a string (one line) which includes a valid JSON where all `"` symbols are escaped (prefixed by the `\` symbol).

To prepare such a string the [./tools/json2var.sh](./tools/json2var.sh) bash script can be used:
- Run it as `./json2var.sh <json_file>`
- Where `<json_file>` - is a valid JSON file which includes the default configuration. Note: comments are not allowed in this file.
- The script adds the `\` symbol where needed, removes unnecessary spaces and new line symbols, and generates the result in the `"DEFAULT_CFG":"<json as string>"` form.
- The result is printed out in the console.
- Copy&paste it as the environment variable.

Note: to run the script on Windows, install [git (with bash component)](http://git-scm.com/download/win) and execute the script with git bash terminal.

Example of a default configuration:
- [./tools/default-cfg.json](./tools/default-cfg.json) - an original default configuration in JSON format
- [./tools/default-cfg.txt](./tools/default-cfg.txt) - `DEFAULT_CFG` environment variable with the string value which corresponds to the original JSON

### User-Defined Environment Variables ###

Are used for sensitive settings, eg. credentials, in production deployments, and to specify [Default Configuration](#default-configuration).

Should be passed to [impcentral Device Group Environment Variables](https://developer.electricimp.com/tools/impcentral/environmentvariables#user-defined-environment-variables) in JSON format

Variables:
- `DEFAULT_CFG` - [Default Configuration](#default-configuration). Always mandatory. 
- `CLOUD_REST_API_URL` - Cloud (Northbound) REST API URL. Mandatory if [Device Evaluation UI](#device-evaluation-ui) is not enabled.
- `CLOUD_REST_API_USERNAME` - Username to access the cloud (Northbound) REST API. Ignored if [Device Evaluation UI](#device-evaluation-ui) is enabled.
- `CLOUD_REST_API_PASSWORD` - Password to access the cloud (Northbound) REST API. Ignored if [Device Evaluation UI](#device-evaluation-ui) is enabled.
- `CFG_REST_API_USERNAME` - Username to access the tracker (Southbound) REST API. Ignored if [Device Evaluation UI](#device-evaluation-ui) is enabled.
- `CFG_REST_API_PASSWORD` - Password to access the tracker (Southbound) REST API. Ignored if [Device Evaluation UI](#device-evaluation-ui) is enabled.
- `GOOGLE_MAPS_API_KEY` - API Key for Google Maps Platform. Required by [Google Maps Geolocation API](https://developers.google.com/maps/documentation/geolocation/overview) to determine the location by cell towers info or by WiFi networks. See [here](https://developers.google.com/maps/documentation/geolocation/get-api-key) how to obtain the Key. Ignored if [Device Evaluation UI](#device-evaluation-ui) is enabled.
- `UBLOX_ASSIST_NOW_TOKEN` - [U-blox AssistNow token](https://www.u-blox.com/en/product/assistnow). Required for downloading of assist data for u-blox GNSS receiver. See [here](https://www.u-blox.com/en/assistnow-service-evaluation-token-request-form) how to obtain the Token. Always mandatory.

Example of JSON with environment variables (when Cloud REST API is [emulated on another Imp](#simple-cloud-emulation)):
```
{
  "CLOUD_REST_API_URL": "https://agent.electricimp.com/7jiDVu1t_w-1", // not a real url
  "CLOUD_REST_API_USERNAME": "test",
  "CLOUD_REST_API_PASSWORD": "test",
  "CFG_REST_API_USERNAME": "test",
  "CFG_REST_API_PASSWORD": "test",
  "GOOGLE_MAPS_API_KEY": "AIzaSyDJQV2m_qNMjdw5snP6qPjdtoMRau-ger8", // not a real key
  "UBLOX_ASSIST_NOW_TOKEN": "CW2lcwNtSE2pHmXYP_LbKP", // not a real token
  "DEFAULT_CFG": "..." // see ./tools/default-cfg.txt
}
```

## First Run Preparation #

Before running the application for the first time make sure that:
- ESP32 chip on the PAT target board has a firmware flashed. For more details see [./docs/esp32_readme.md](./docs/esp32_readme.md)
- Imp-Device SPI flash is clean (has no "garbage").
- Imp-Device [User Configuration Storage](https://developer.electricimp.com/resources/permanentstore) is clean (has no data).
- Imp-Agent [Persistent Data](https://developer.electricimp.com/examples/agentdatapersistence) is clean (has no data).

Note, the application goes first to the Shipping mode when [User Configuration Storage](https://developer.electricimp.com/resources/permanentstore) is clean or contains a special application-specific setting. Otherwise, the application considers that the tracker is already "shipped" and starts the normal operation.

For production devices it is assumed that the first run preparation is done by a factory code.

For development devices, if needed, the first run preparation steps can be done manually:
- To reflash ESP32 firmware - see [./docs/esp32_readme.md](./docs/esp32_readme.md)
- To clean Imp-Device SPI flash - build and run the application with the `ERASE_MEMORY` [Builder Variable](#builder-variables)
- To clean Imp-Device [User Configuration Storage](https://developer.electricimp.com/resources/permanentstore) (re-initiate the Shipping mode) - run a simple application on Imp-Device with the ["imp.setuserconfiguration(null);"](https://developer.electricimp.com/api/imp/setuserconfiguration) call before running the Asset Tracker application.
- To clean Imp-Agent [Persistent Data](https://developer.electricimp.com/examples/agentdatapersistence) - run a simple application on Imp-Agent with the ["server.save({});"](https://developer.electricimp.com/api/server/save) call before running the Asset Tracker application.

## Build And Run ##

- If no need to change the default values of [Builder Variables](#builder-variables), take already preprocessed files from the [./build](./build) folder.
- Otherwise:
  - Specify [Builder Variables](#builder-variables), if needed.
  - Run [Builder](https://github.com/electricimp/Builder/) for [./src/agent/Main.agent.nut](./src/agent/Main.agent.nut) file to get Imp-Agent preprocessed file.
  - Run [Builder](https://github.com/electricimp/Builder/) for [./src/device/Main.device.nut](./src/device/Main.device.nut) file to get Imp-Device preprocessed file.
- Specify settings required by your build as the [Environment Variable](#user-defined-environment-variables) in the impcentral Device Group where you plan to run the application.
- Create and build a new deployment in the Device Group and restart Imp.
- Control the application behavior using different ways:
  - logs in the impcentral,
  - [UART logging](#uart-logging) (if enabled),
  - [LED indication](#led-indication) (if enabled),
  - [Device Evaluation UI](#device-evaluation-ui) (if enabled),
  - a remote service which implements the [Northbound REST API](./docs/northbound-api.md),
  - a remote service which interacts with the Asset Tracker application via the [Southbound REST API](./docs/southbound-api.md).

## Configuration And Behavior ##

[Default Configuration](#default-configuration) of the Asset Tracker application can be updated in runtime. For all details, as well as the application behavior description, see the [Southbound REST API](./docs/southbound-api.md).

## Cloud Integration ##

The Asset Tracker application sends data to a cloud. For all details see the [Northbound REST API](./docs/northbound-api.md).

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
    - Movement detected: **magenta**
    - Motion started alert: **white**
    - Motion stopped alert: **cyan**
    - Temperature is low alert: **blue**
    - Temperature is high alert: **yellow**
  - When the indication is disabled, the User LED is not in use.

### Device Evaluation UI ###

When enabled by the [Builder variable](#builder-variables) Imp-Agent provides a simple Web UI for checking the Asset Tracker application status and allowing its configuration. This is helpful for testing and debugging, and for demo purposes as well.

To access the Web UI open `https://<tracker_api_url>` URL (no additional endpoint) in a Web browser. Where `<tracker_api_url>` - is the Imp-Agent URL. It comprises the base URL `agent.electricimp.com` plus the [agent’s ID](https://developer.electricimp.com/faqs/terminology#agent). Example: `https://agent.electricimp.com/7jiDVu1t_w--`

The Web UI does not require any user credentials to access.

The UI includes the following capabilities:
- Displaying the latest data reported by the Asset Tracker application (the latest data message received from Imp-Device, this is not necessary a message with the latest timestamp). Note, in parallel with displaying in this UI the data messages still can be forwarded to a cloud, if the cloud URL and credentials are specified (see below).
- Displaying a history of alerts reported by the Asset Tracker application (several latest alerts received from Imp-Device, they are not necessary sorted by alert timestamps).
- Requesting, displaying, updating and applying the Asset Tracker application configuration. For the configuration description see the [Southbound REST API](./docs/southbound-api.md).
- Specifying the Asset Tracker application settings - the same which are specified by the [Environment Variables](#user-defined-environment-variables) for production deployments:
  - Tokens / Access keys. Note, there are no defaults for these tokens, for the full functionality of the Asset Tracker application the tokens should be manually specified.
  - URL and credentials of a cloud that implements the [Northbound REST API](./docs/northbound-api.md). Optional. If specified, then the data messages are forwarded to the cloud, in parallel with the Web UI.
  - Note, credentials to access the [Southbound REST API](./docs/southbound-api.md) are not needed. It is still possible to access this API from a cloud, in parallel with working via the Web UI. No authentication is needed in this case.
  - Note, all specified settings are lost after the application redeployment or Imp-Agent restart.

### Emergency Mode ###

If an unhandled error has occurred, the tracker application:
- saves the error,
- stops all activities,
- goes to the "sleep" mode,
- wakes up periodically or if the photoresistor detects light:
  - connects to the imp-central server,
  - logs the saved error,
  - waits for an application update.

## License ##

The application is licensed under the [MIT License](./LICENSE).
