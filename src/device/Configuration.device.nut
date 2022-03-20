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

// Geofence zone:
// NOTE: The current settings are fake/example only.

// Geofence zone center latitude, in degrees, [-90..90]
const DEFAULT_GEOFENCE_CENTER_LAT = 1.0;
// Geofence zone center longitude, in degrees, [-180..180]
const DEFAULT_GEOFENCE_CENTER_LNG = 2.0;
// Geofence zone radius, in meters, [0..EARTH_RADIUS]
const DEFAULT_GEOFENCE_RADIUS = 1.0;

// BLE devices and their locations
// NOTE: The current settings are fake/example only.
DEFAULT_BLE_DEVICES <- {
    // This key may contain an empty table but it must be present
    "generic": {
        "656684e1b306": {
            "lat": 1,
            "lng": 2
        }
    },
    // This key may contain an empty table but it must be present
    "iBeacon": {
        "\x01\x12\x23\x34\x45\x56\x67\x78\x89\x9a\xab\xbc\xcd\xde\xef\xf0": {
            [1800] = {
                [1286] = { "lat": 10, "lng": 20 }
            }
        }
    }
};
