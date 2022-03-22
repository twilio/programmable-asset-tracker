#require "rocky.class.nut:2.0.2"
#require "Messenger.lib.nut:0.2.0"

@include once "../src/shared/Constants.shared.nut"
@include once "../src/shared/Logger/Logger.shared.nut"
@include once "../src/agent/CfgService.agent.nut"


// ---------------------------- THE MAIN CODE ---------------------------- //

Logger.setLogLevel(LGR_LOG_LEVEL.DEBUG);
::info("Configuration service test started");

// Initialize library for communication with Imp-Device
msngr <- Messenger();
rocky <- Rocky();
cfgService <- CfgService(msngr, rocky);
cfgService.init();