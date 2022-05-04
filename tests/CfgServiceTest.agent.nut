#require "rocky.class.nut:2.0.2"
#require "Messenger.lib.nut:0.2.0"

@include once "../src/shared/Constants.shared.nut"
@include once "../src/shared/Logger/Logger.shared.nut"
@include once "../src/agent/CfgValidation.agent.nut"
@include once "../src/agent/CfgService.agent.nut"

// send configuration via curl example (cfg.json is located in the same directory):
// curl -u test:test -k --data '@cfg.json' -H "content-type: application/json" -X PATCH https://agent.electricimp.com/D7u-IqX1x6j1/cfg
// get configuration example:
// curl -u test:test -k -X GET https://agent.electricimp.com/D7u-IqX1x6j1/cfg

// cfg.json example:
// {
//   "configuration":
//   {
//     "updateId": "1111",

//     "locationTracking": {

//       "locReadingPeriod": 180.0,

//       "alwaysOn": false,

//       "motionMonitoring": {
//         "enabled": true,
//         "movementAccMin": 0.15,
//         "movementAccMax": 0.30,
//         "movementAccDur": 0.25,
//         "motionTime": 5.0,
//         "motionVelocity": 0.25,
//         "motionDistance": 3.0,

//         "motionStopTimeout": 10.0
//       },

//       "repossessionMode": {
//         "enabled": true,
//         "after": 1667598736
//       },

//       "bleDevices": {
//         "enabled": false,
//         "generic": {

//         },
//         "iBeacon": {

//         }
//       },

//       "geofence": {
//         "enabled": false,
//         "lng": 0.0,
//         "lat": 0.0,
//         "radius": 0.0
//       }
//     },

//     "connectingPeriod": 180.0,

//     "readingPeriod": 60.0,

//     "alerts": {

//       "shockDetected" : {
//         "enabled": true,
//         "threshold": 8.0
//       },

//       "temperatureLow": {
//         "enabled": true,
//         "threshold": 10.0,
//         "hysteresis": 1.0
//       },

//       "temperatureHigh": {
//         "enabled": true,
//         "threshold": 25.0,
//         "hysteresis": 1.0
//       },

//       "batteryLow": {
//         "enabled": false,
//         "threshold": 12.0
//       },

//       "tamperingDetected": {
//         "enabled": false
//       }
//     },

//     "debug": {
//       "logLevel": "DEBUG"
//     }
//   },
//   "agentConfiguration": {
//     "debug": {
//       "logLevel": "INFO"
//     }
//   }
// }

// ---------------------------- THE MAIN CODE ---------------------------- //

/**
 * Initialize Logger by settings from Imp-agent persistent memory
 */
function initLoggerSettings() {
    local storedAgentData = server.load();
    if (!("deploymentId" in storedAgentData)) {
        ::debug("No saved deployment ID found");
    } else if (storedAgentData["deploymentId"] == __EI.DEPLOYMENT_ID) {
        local logLevel = "agentLogLevel" in storedAgentData ? 
                         storedAgentData["agentLogLevel"] : 
                         null;
        if (logLevel) {
            ::info("Imp-agent log level is set to \"" + logLevel + "\"");
            Logger.setLogLevelStr(logLevel);
        } else {
            ::debug("No saved imp-agent log level found");
        }
    } else {
        ::debug("Current Deployment Id: " + 
                __EI.DEPLOYMENT_ID + 
                " - is not equal to the stored one");
    }
}

initLoggerSettings();
::info("Configuration service test started");

// Initialize library for communication with Imp-Device
msngr <- Messenger();
rocky <- Rocky();
cfgService <- CfgService(msngr, rocky);