// Configuration settings for imp-device

// Data reading period, in seconds
const DEFAULT_DATA_READING_PERIOD =

// Data sending period, in seconds
const DEFAULT_DATA_SENDING_PERIOD =

// Alert settings:

// Temperature high alert threshold, in Celsius
const DEFAULT_TEMPERATURE_HIGH = 
// Temperature low alert threshold, in Celsius
const DEFAULT_TEMPERATURE_LOW = 
// Battery low alert threshold, in %
const DEFAULT_BATTERY_LOW = 
// Shock acceleration alert threshold, in g
const DEFAULT_SHOCK_THRESHOLD = 

// Tracking settings:

// Tracking is enabled (true) or disabled (false)
const DEFAULT_TRACKING_ENABLED = true;
// Location reading period, in seconds
const DEFAULT_LOCATION_READING_PERIOD =

// Motion start detection settings:

// Movement acceleration threshold range [min..max]:
// - minimum (starting) level, in g
const DEFAULT_MOVEMENT_ACCELERATION_MIN =
// - maximum level, in g
const DEFAULT_MOVEMENT_ACCELERATION_MAX =
// Duration of exceeding movement acceleration threshold, in seconds
const DEFAULT_MOVEMENT_ACCELERATION_DURATION =
// Maximum time to determine motion detection after the initial movement, in seconds
const DEFAULT_MOTION_TIME =
// Minimum instantaneous velocity  to determine motion detection condition, in meters per second
const DEFAULT_MOTION_VELOCITY =
// Minimal movement distance to determine motion detection condition, in meters.
// If 0, distance is not calculated (not used for motion detection)
const DEFAULT_MOTION_DISTANCE = 

// Geofence settings:
// Geofencing is enabled (true) or disabled (false)
const DEFAULT_GEOFENCE_ENABLED = false;
// TBD

// BLE Beacons settings: TBD
