@include "../shared/Version.shared.nut"
@include "../shared/Logger.shared.nut"

// Main application on Imp-Device:
// - TBD

class Application {

    /**
     * Application Constructor
     */
    constructor() {
        ::info("Application Version: " + APP_VERSION);
        ::debug("Wake reason: " + hardware.wakereason());
    }

    // -------------------- PRIVATE METHODS -------------------- //

}

// Set Log Level
Logger.setLogLevel(LGR_LOG_LEVEL.DEBUG);

// Run the application
app <- Application();
