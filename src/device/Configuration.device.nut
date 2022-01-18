// Configuration settings for imp-device

// Data reading period, in seconds
const DEFAULT_DATA_READING_PERIOD = 20.0;

// Data sending period, in seconds
const DEFAULT_DATA_SENDING_PERIOD = 60.0;

// Alert settings:

// Temperature high alert threshold, in Celsius
const DEFAULT_TEMPERATURE_HIGH =  25.0;
// Temperature low alert threshold, in Celsius
const DEFAULT_TEMPERATURE_LOW = 10.0;

// Battery low alert threshold, in %
const DEFAULT_BATTERY_LOW = 7.0; // not supported

// Shock acceleration alert threshold, in g
// IMPORTANT: This value affects the measurement range and accuracy of the accelerometer:
// the larger the range - the lower the accuracy.
// This can affect the effectiveness of the MOVEMENT_ACCELERATION_MIN constant.
// For example: if SHOCK_THRESHOLD > 4.0 g, then MOVEMENT_ACCELERATION_MIN should be > 0.1 g
const DEFAULT_SHOCK_THRESHOLD = 8.0;

// Location tracking settings:

// Location reading period, in seconds
const DEFAULT_LOCATION_READING_PERIOD = 180.0;

// Motion start detection settings:

// Movement acceleration threshold range [min..max]:
// - minimum (starting) level, in g
const DEFAULT_MOVEMENT_ACCELERATION_MIN = 0.2;
// - maximum level, in g
const DEFAULT_MOVEMENT_ACCELERATION_MAX = 0.4;
// Duration of exceeding movement acceleration threshold, in seconds
const DEFAULT_MOVEMENT_ACCELERATION_DURATION = 0.25;
// Maximum time to determine motion detection after the initial movement, in seconds
const DEFAULT_MOTION_TIME = 15.0;
// Minimum instantaneous velocity to determine motion detection condition, in meters per second
const DEFAULT_MOTION_VELOCITY = 0.5;
// Minimal movement distance to determine motion detection condition, in meters.
// If 0, distance is not calculated (not used for motion detection)
const DEFAULT_MOTION_DISTANCE = 5.0;
