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
// set agent debug level:
// curl -u test:test -k --data '{"debug":{"agentLogLevel":"DEBUG"}}' -H "content-type: application/json" -X PATCH https://agent.electricimp.com/D7u-IqX1x6j1/cfg

// cfg.json example:
// {
// "configuration": {
// "updateId": "123567878990",
// "locationTracking": {
//     "locReadingPeriod": 300.0,
//     "alwaysOn": false,
//     "motionMonitoring": {
//       "enabled": true,
//       "movementAccMin": 0.1,
//       "movementAccMax": 0.4,
//       "movementAccDur": 0.6,
//       "motionTime": 10.0,
//       "motionVelocity": 5.0,
//       "motionDistance": 0.0
//     },
//     "repossessionMode": {
//       "enabled": true,
//       "after": "1648841000"
//     },
//     "bleDevices": {
//         "enabled": true,
//         "generic": {
//         "6f928a04e179": {
//           "lng": 10.0,
//           "lat": 23.0 
//         }
//       },
//       "iBeacon": {
//         "646be3e46e4e4e25ad0177a28f3df4bd": {
//           "15655": {
//             "2": {
//               "lng": 11.0,
//               "lat": 24.0
//             }
//           }
//         }
//       }
//     },
//     "geofence": {
//       "enabled": true,
//       "lng": 27.0,
//       "lat": 28.0,
//       "radius": 2500.0
//     }
// },
// "connectingPeriod": 100.0,
// "readingPeriod": 3600.0,
// "alerts": {
//     "shockDetected" : {
//       "enabled": true,
//       "threshold": 8.0
//     },
//     "temperatureLow": {
//       "enabled": true,
//       "threshold": 10.0,
//       "hysteresis": 1.0
//     },
//     "temperatureHigh": {
//       "enabled": true,
//       "threshold": 30.0,
//       "hysteresis": 1.0
//     },
//     "batteryLow": {
//       "enabled": true,
//       "threshold": 10.0
//     },
//     "tamperingDetected": {
//       "enabled": true
//     }
//   }
// },
// "debug": {
//   "agentLogLevel": "DEBUG",
//   "deviceLogLevel": "INFO"
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
cfgService.init();