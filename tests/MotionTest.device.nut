// This example tests MotionMonitor class behavior:
// - motion detection start/stop
// - shock detection

#require "LIS3DH.device.lib.nut:3.0.0"

@include once "../src/shared/Logger.shared.nut"
@include once "../src/device/MotionMonitor.device.nut"

function motionTestCb(start) {
    if (start)
        ::info(format("Motion start"));
    else
        ::info(format("Motion stop"));
}

function shockTestCb() {
    ::info("Shock");
}

Logger.setLogLevel(LGR_LOG_LEVEL.DEBUG);

::info("Test started...");

mm <- MotionMonitor(hardware.i2c89, hardware.pin1);

mm.setMotionCb(motionTestCb.bindenv(this));
mm.setShockCb(shockTestCb.bindenv(this));
mm.enableMotionDetection(true);
mm.enableShockDetection(true);
