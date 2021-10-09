// Configuration settings for imp-device

// Data reading period, in seconds
const DEFAULT_DATA_READING_PERIOD = 60.0;

// Data sending period, in seconds
const DEFAULT_DATA_SENDING_PERIOD = 600.0;

// Alert settings:

// Temperature high alert threshold, in Celsius
const DEFAULT_TEMPERATURE_HIGH =  30.0;
// Temperature low alert threshold, in Celsius
const DEFAULT_TEMPERATURE_LOW = 10.0;
// Battery low alert threshold, in %
const DEFAULT_BATTERY_LOW = 7.0;
// Shock acceleration alert threshold, in g
const DEFAULT_SHOCK_THRESHOLD = 2.0;

// Tracking settings:

// Tracking is enabled (true) or disabled (false)
const DEFAULT_TRACKING_ENABLED = 1;
// Location reading period, in seconds
const DEFAULT_LOCATION_READING_PERIOD = 300.0;

// Motion start detection settings:

// Movement acceleration threshold range [min..max]:
// - minimum (starting) level, in g
const DEFAULT_MOVEMENT_ACCELERATION_MIN = 0.1;
// - maximum level, in g
const DEFAULT_MOVEMENT_ACCELERATION_MAX = 0.3;
// Duration of exceeding movement acceleration threshold, in seconds
const DEFAULT_MOVEMENT_ACCELERATION_DURATION = 0.5;
// Maximum time to determine motion detection after the initial movement, in seconds
const DEFAULT_MOTION_TIME = 20.0;
// Minimum instantaneous velocity  to determine motion detection condition, in meters per second
const DEFAULT_MOTION_VELOCITY = 0.6;
// Minimal movement distance to determine motion detection condition, in meters.
// If 0, distance is not calculated (not used for motion detection)
const DEFAULT_MOTION_DISTANCE = 5.0;

// Geofence settings:
// Geofencing is enabled (true) or disabled (false)
const DEFAULT_GEOFENCE_ENABLED = 0;
// TBD

// BLE Beacons settings: TBD
