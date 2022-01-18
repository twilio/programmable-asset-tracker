#require "LIS3DH.device.lib.nut:3.0.0"

@include once "../src/shared/Logger/Logger.shared.nut"
@include once "../src/device/AccelerometerDriver.device.nut"

// Test for AccelerometerDriver:
// - sets shock detection callback, logs shock event
// - enables motion detection, logs motion event
// - re-enables motion detection after TEST_MOTION_CHECK_DELAY

// Settings for manual testing:

// Table profile
// ------------------------------------------------
// Acceleration threshold for shock detection, in g
const TEST_SHOCK_THR_TABLE = 4.0;

// Movement acceleration maximum threshold, in g
const TEST_MOV_MAX_TABLE = 0.3;

// Movement acceleration minimum threshold, in g
const TEST_MOV_MIN_TABLE = 0.1;

// Duration of exceeding the movement acceleration threshold, in seconds
const TEST_MOV_DUR_TABLE = 0.25;

// Maximum time to determine motion detection after the initial movement, in seconds
const TEST_MOTION_TIME_TABLE = 2.0;

// Minimum instantaneous velocity to determine motion detection condition, in meters per second
const TEST_MOTION_VEL_TABLE = 0.25;

// Minimal movement distance to determine motion detection condition, in meters
const TEST_MOTION_DIST_TABLE = 0.4;

// Walking profile
// ------------------------------------------------
// Acceleration threshold for shock detection, in g
const TEST_SHOCK_THR_WALK = 8.0;

// Movement acceleration maximum threshold, in g
const TEST_MOV_MAX_WALK = 0.4;

// Movement acceleration minimum threshold, in g
const TEST_MOV_MIN_WALK = 0.2;

// Duration of exceeding the movement acceleration threshold, in seconds
const TEST_MOV_DUR_WALK = 0.25;

// Maximum time to determine motion detection after the initial movement, in seconds
const TEST_MOTION_TIME_WALK = 15.0;

// Minimum instantaneous velocity to determine motion detection condition, in meters per second
const TEST_MOTION_VEL_WALK = 0.5;

// Minimal movement distance to determine motion detection condition, in meters
const TEST_MOTION_DIST_WALK = 5.0;

// Delay between motion event and enabling the next motion detection, in seconds
const TEST_MOTION_CHECK_DELAY = 15;

/**
 * Motion detection callback
 */
function motionTestCb() {
    ::info("Motion detected");

    imp.wakeup(TEST_MOTION_CHECK_DELAY, function () {
            ad.detectMotion(motionTestCb.bindenv(this), {"movementMax"      : TEST_MOV_MAX_WALK,
                                                         "movementMin"      : TEST_MOV_MIN_WALK,
                                                         "movementDur"      : TEST_MOV_DUR_WALK,
                                                         "motionTimeout"    : TEST_MOTION_TIME_WALK,
                                                         "motionVelocity"   : TEST_MOTION_VEL_WALK,
                                                         "motionDistance"   : TEST_MOTION_DIST_WALK});
            ::info("Motion detection re-enabled");
        }.bindenv(this));
}

/**
 * Shock detection callback
 */
function shockTestCb() {
    ::info("Shock detected");
}

Logger.setLogLevel(LGR_LOG_LEVEL.INFO);
::info("Accelerometer test started");

try {
    ad <- AccelerometerDriver(hardware.i2cLM, hardware.pinW);
    ad.enableShockDetection(shockTestCb.bindenv(this), {"shockThreshold" : TEST_SHOCK_THR_WALK});
    ad.detectMotion(motionTestCb.bindenv(this), {"movementMax"      : TEST_MOV_MAX_WALK,
                                                 "movementMin"      : TEST_MOV_MIN_WALK,
                                                 "movementDur"      : TEST_MOV_DUR_WALK,
                                                 "motionTimeout"    : TEST_MOTION_TIME_WALK,
                                                 "motionVelocity"   : TEST_MOTION_VEL_WALK,
                                                 "motionDistance"   : TEST_MOTION_DIST_WALK});
    ::info("Motion and shock detection enabled");
} catch (e) {
    ::error(e);
}
