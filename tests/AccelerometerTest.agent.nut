@include once "../src/shared/Version.shared.nut"
@include once "../src/shared/Logger.shared.nut"

// Main application on Imp-Agent:
// - TBD

class Application {

    /**
     * Application Constructor
     */
    constructor() {
        ::info("Application Version: " + APP_VERSION);
    }

    // -------------------- PRIVATE METHODS -------------------- //

}

// Set Log Level
Logger.setLogLevel(LGR_LOG_LEVEL.DEBUG);

// Run the application
app <- Application();