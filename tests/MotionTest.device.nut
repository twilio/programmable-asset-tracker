// This example tests MotionMonit class behavior:
// - motion detection start/stop
// - shock detection

@include once "../src/shared/Logger.shared.nut"
@include once "../src/device/MotionMonitor.device.nut"

// Set Log Level
Logger.setLogLevel(LGR_LOG_LEVEL.DEBUG);
