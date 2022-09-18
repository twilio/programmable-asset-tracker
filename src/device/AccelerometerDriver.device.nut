@set CLASS_NAME = "AccelerometerDriver" // Class name for logging

// Accelerometer Driver class:
// - utilizes LIS2DH12 accelerometer connected via I2C
// - detects motion start event
// - detects shock event

// Shock detection:
// ----------------
// see description of the enableShockDetection() method.

// Motion start detection:
// -----------------------
// It is enabled and configured by the detectMotion() method - see its description.
// When enabled, motion start detection consists of two steps:
//   1) Waiting for initial movement detection.
//   2) Confirming the motion during the specified time.
//
// If the motion is confirmed, it is reported and the detection is disabled
// (it should be explicitly re-enabled again, if needed),
// If the motion is not confirmed, return to the step #1 - wait for a movement.
// The movement acceleration threshold is slightly increased in this case
// (between configured min and max values).
// Is reset to the min value once the motion is confirmed.
//
// Motion confirming is based on the two conditions currently:
//   a) If velocity exceeds the specified value and is not zero at the end of the specified time.
//   b) Optional: if distance after the initial movement exceeds the specified value.

// Default I2C address of the connected LIS2DH12 accelerometer
const ACCEL_DEFAULT_I2C_ADDR = 0x32;

// Default Measurement rate - ODR, in Hz
const ACCEL_DEFAULT_DATA_RATE = 100;

// Defaults for shock detection:
// -----------------------------

// Acceleration threshold, in g
const ACCEL_DEFAULT_SHOCK_THR = 8.0; // (for LIS2DH12 register 0x3A)

// Defaults for motion detection:
// ------------------------------

// Duration of exceeding the movement acceleration threshold, in seconds
const ACCEL_DEFAULT_MOV_DUR  = 0.25;
// Movement acceleration maximum threshold, in g
const ACCEL_DEFAULT_MOV_MAX = 0.4;
// Movement acceleration minimum threshold, in g
const ACCEL_DEFAULT_MOV_MIN = 0.2;
// Step change of movement acceleration threshold for bounce filtering, in g
const ACCEL_DEFAULT_MOV_STEP = 0.1;
// Default time to determine motion detection after the initial movement, in seconds.
const ACCEL_DEFAULT_MOTION_TIME = 10.0;
// Default instantaneous velocity to determine motion detection condition, in meters per second.
const ACCEL_DEFAULT_MOTION_VEL = 0.5;
// Default movement distance to determine motion detection condition, in meters.
// If 0, distance is not calculated (not used for motion detection).
const ACCEL_DEFAULT_MOTION_DIST = 0.0;

// Internal constants:
// -------------------
// Acceleration range, in g.
const ACCEL_RANGE = 8;
// Acceleration of gravity (m / s^2)
const ACCEL_G = 9.81;
// Default accelerometer's FIFO watermark
const ACCEL_DEFAULT_WTM = 8;
// Velocity zeroing counter (for stop motion)
const ACCEL_VELOCITY_RESET_CNTR = 4;
// Discrimination window applied low threshold
const ACCEL_DISCR_WNDW_LOW_THR = -0.09;
// Discrimination window applied high threshold
const ACCEL_DISCR_WNDW_HIGH_THR = 0.09;

// States of the motion detection - FSM (finite state machine)
enum ACCEL_MOTION_STATE {
    // Motion detection is disabled (initial state; motion detection is disabled automatically after motion is detected)
    DISABLED = 1,
    // Motion detection is enabled, waiting for initial movement detection
    WAITING = 2,
    // Motion is being confirmed after initial movement is detected
    CONFIRMING = 3
};

const LIS2DH12_CTRL_REG2 = 0x21; // HPF config
const LIS2DH12_REFERENCE = 0x26; // Reference acceleration/tilt value.
const LIS2DH12_HPF_AOI_INT1 = 0x01; // High-pass filter enabled for AOI function on Interrupt 1.
const LIS2DH12_FDS = 0x08; // Filtered data selection. Data from internal filter sent to output register and FIFO.
const LIS2DH12_FIFO_SRC_REG  = 0x2F; // FIFO state register.
const LIS2DH12_FIFO_WTM = 0x80; // Set high when FIFO content exceeds watermark level.
const LIS2DH12_OUT_T_H = 0x0D; // Measured temperature (High byte)
const LIS2DH12_TEMP_EN = 0xC0; // Temperature enable bits (11 - Enable)
const LIS2DH12_BDU = 0x80; // Block Data Update bit (0 - continuous update; default)

// Vector of velocity and movement class.
// Vectors operation in 3D.
class FloatVector {

    // x coordinat
    _x = null;

    // y coordinat
    _y = null;

    // z coordinat
    _z = null;

    /**
     * Constructor for FloatVector Class
     *
     * @param {float} x - Start x coordinat of vector.
     *                       Default: 0.0
     * @param {float} y - Start y coordinat of vector.
     *                       Default: 0.0
     * @param {float} z - Start z coordinat of vector.
     *                       Default: 0.0
     */
    constructor(x = 0.0, y = 0.0, z = 0.0) {
        _x = x;
        _y = y;
        _z = z;
    }

    /**
     * Calculate vector length.
     *
     * @return {float} Current vector length.
     */
    function length() {
        return math.sqrt(_x*_x + _y*_y + _z*_z);
    }

    /**
     * Clear vector (set 0.0 to all coordinates).
     */
    function clear() {
        _x = 0.0;
        _y = 0.0;
        _z = 0.0;
    }

    /**
     * Overload of operation additions for vectors.
     *                                     _ _
     * @return {FloatVector} Result vector X+Y.
     * An exception will be thrown in case of argument is not a FloatVector.
     */
    function _add(val) {
        if (typeof val != "FloatVector") throw "Operand is not a Vector object";
        return FloatVector(_x + val._x, _y + val._y, _z + val._z);
    }

    /**
     * Overload of operation subtractions for vectors.
     *                                     _ _
     * @return {FloatVector} Result vector X-Y.
     * An exception will be thrown in case of argument is not a FloatVector.
     */
    function _sub(val) {
        if (typeof val != "FloatVector") throw "Operand is not a Vector object";
        return FloatVector(_x - val._x, _y - val._y, _z - val._z);
    }

    /**
     * Overload of operation assignment for vectors.
     *
     * @return {FloatVector} Result vector.
     * An exception will be thrown in case of argument is not a FloatVector.
     */
    function _set(val) {
        if (typeof val != "FloatVector") throw "Operand is not a Vector object";
        return FloatVector(val._x, val._y, val._z);
    }

    /**
     * Overload of operation division for vectors.
     *                                             _
     * @return {FloatVector} Result vector (1/alf)*V.
     * An exception will be thrown in case of argument is not a float value.
     */
    function _div(val) {
        if (typeof val != "float") throw "Operand is not a float number";
        return FloatVector(val > 0.0 || val < 0.0 ? _x/val : 0.0,
                           val > 0.0 || val < 0.0 ? _y/val : 0.0,
                           val > 0.0 || val < 0.0 ? _z/val : 0.0);
    }

    /**
     * Overload of operation multiplication for vectors and scalar.
     *                                         _
     * @return {FloatVector} Result vector alf*V.
     * An exception will be thrown in case of argument is not a float value.
     */
    function _mul(val) {
        if (typeof val != "float") throw "Operand is not a float number";
        return FloatVector(_x*val, _y*val, _z*val);
    }

    /**
     * Return type.
     *
     * @return {string} Type name.
     */
    function _typeof() {
        return "FloatVector";
    }

    /**
     * Convert class data to string.
     *
     * @return {string} Class data.
     */
    function _tostring() {
        return (_x + "," + _y + "," + _z);
    }
}

// Accelerometer Driver class.
// Determines the motion and shock detection.
class AccelerometerDriver {
    // enable / disable motion detection
    _enMtnDetect = null;

    // enable / disable shock detection
    _enShockDetect = null;

    // motion detection callback function
    _mtnCb = null;

    // shock detection callback function
    _shockCb = null;

    // pin connected to accelerometer int1 (interrupt check)
    _intPin = null;

    // accelerometer object
    _accel = null;

    // shock threshold value
    _shockThr = null

    // duration of exceeding the movement acceleration threshold
    _movementAccDur = null;

    // current movement acceleration threshold
    _movementCurThr = null;

    // maximum value of acceleration threshold for bounce filtering
    _movementAccMax = null;

    // minimum value of acceleration threshold for bounce filtering
    _movementAccMin = null;

    // maximum time to determine motion detection after the initial movement
    _motionTime = null;

    // timestamp of the movement
    _motionCurTime = null;

    // minimum instantaneous velocity to determine motion detection condition
    _motionVelocity = null;

    // minimal movement distance to determine motion detection condition
    _motionDistance = null;

    // current value of acceleration vector
    _accCur = null;

    // previous value of acceleration vector
    _accPrev = null;

    // current value of velocity vector
    _velCur = null;

    // previous value of velocity vector
    _velPrev = null;

    // current value of position vector
    _positionCur = null;

    // previous value of position vector
    _positionPrev = null;

    // counter for stop motion detection x axis
    _cntrAccLowX = null;

    // counter for stop motion detection y axis
    _cntrAccLowY = null;

    // counter for stop motion detection z axis
    _cntrAccLowZ = null;

    // initial state of motion FSM
    _motionState = null;

    // Flag = true, if minimal velocity for motion detection is exceeded
    _thrVelExceeded = null;

    /**
     * Constructor for Accelerometer Driver Class
     *
     * @param {object} i2c - I2C object connected to accelerometer
     * @param {object} intPin - Hardware pin object connected to accelerometer int1 pin
     * @param {integer} addr - I2C address of accelerometer. Optional.
     *                         Default: ACCEL_DEFAULT_I2C_ADDR
     * An exception will be thrown in case of accelerometer configuration error.
     */
    constructor(i2c, intPin, addr = ACCEL_DEFAULT_I2C_ADDR) {
        _enMtnDetect = false;
        _enShockDetect = false;
        _thrVelExceeded = false;
        _shockThr = ACCEL_DEFAULT_SHOCK_THR;
        _movementCurThr = ACCEL_DEFAULT_MOV_MIN;
        _movementAccMin = ACCEL_DEFAULT_MOV_MIN;
        _movementAccMax = ACCEL_DEFAULT_MOV_MAX;
        _movementAccDur = ACCEL_DEFAULT_MOV_DUR;
        _motionCurTime = time();
        _motionVelocity = ACCEL_DEFAULT_MOTION_VEL;
        _motionTime = ACCEL_DEFAULT_MOTION_TIME;
        _motionDistance = ACCEL_DEFAULT_MOTION_DIST;

        _velCur = FloatVector();
        _velPrev = FloatVector();
        _accCur = FloatVector();
        _accPrev = FloatVector();
        _positionCur = FloatVector();
        _positionPrev = FloatVector();

        _cntrAccLowX = ACCEL_VELOCITY_RESET_CNTR;
        _cntrAccLowY = ACCEL_VELOCITY_RESET_CNTR;
        _cntrAccLowZ = ACCEL_VELOCITY_RESET_CNTR;

        _motionState = ACCEL_MOTION_STATE.DISABLED;

        _intPin = intPin;

        try {
            _accel = LIS3DH(i2c, addr);
            _accel.reset();
            local range = _accel.setRange(ACCEL_RANGE);
            ::info(format("Accelerometer range +-%d g", range), "@{CLASS_NAME}");
            local rate = _accel.setDataRate(ACCEL_DEFAULT_DATA_RATE);
            ::debug(format("Accelerometer rate %d Hz", rate), "@{CLASS_NAME}");
            _accel.setMode(LIS3DH_MODE_LOW_POWER);
            _accel.enable(true);
            _accel._setReg(LIS2DH12_CTRL_REG2, LIS2DH12_FDS | LIS2DH12_HPF_AOI_INT1);
            _accel._getReg(LIS2DH12_REFERENCE);
            _accel.configureFifo(true, LIS3DH_FIFO_BYPASS_MODE);
            _accel.configureFifo(true, LIS3DH_FIFO_STREAM_TO_FIFO_MODE);
            _accel.getInterruptTable();
            // TODO: Disable the pin when it's not in use to save power?
            _intPin.configure(DIGITAL_IN_WAKEUP, _checkInt.bindenv(this));
            _accel._getReg(LIS2DH12_REFERENCE);
            ::debug("Accelerometer configured", "@{CLASS_NAME}");
        } catch (e) {
            throw "Accelerometer configuration error: " + e;
        }
    }

    /**
     * Get temperature value from internal accelerometer thermosensor.
     *
     * @return {float} Temperature value in degrees Celsius.
     */
    function readTemperature() {
        // To convert the raw data to celsius
        const ACCEL_TEMP_TO_CELSIUS = 25.0;
        // Calibration offset for temperature.
        // By default, accelerometer can only provide temperature variaton, not the precise value.
        // NOTE: This value may be inaccurate for some devices. It was chosen based only on two devices
        const ACCEL_TEMP_CALIBRATION_OFFSET = -8.0;
        // Delay to allow the sensor to make a measurement, in seconds
        const ACCEL_TEMP_READING_DELAY = 0.01;

        _switchTempSensor(true);

        imp.sleep(ACCEL_TEMP_READING_DELAY);

        local high = _accel._getReg(LIS2DH12_OUT_T_H);
        local res = (high << 24) >> 24;

        _switchTempSensor(false);

        return res + ACCEL_TEMP_TO_CELSIUS + ACCEL_TEMP_CALIBRATION_OFFSET;
    }

    /**
     * Enables or disables a shock detection.
     * If enabled, the specified callback is called every time the shock condition is detected.
     * @param {function} shockCb - Callback to be called every time the shock condition is detected.
     *        The callback has no parameters. If null or not a function, the shock detection is disabled.
     *        Otherwise, the shock detection is (re-)enabled for the provided shock condition.
     * @param {table} shockCnd - Table with the shock condition settings.
     *        Optional, all settings have defaults.
     *        The settings:
     *          "shockThreshold": {float} - Shock acceleration threshold, in g.
     *                                      Default: ACCEL_DEFAULT_SHOCK_THR
     */
    function enableShockDetection(shockCb, shockCnd = {}) {
        local shockSettIsCorr = true;
        _shockThr = ACCEL_DEFAULT_SHOCK_THR;
        foreach (key, value in shockCnd) {
            if (typeof key == "string") {
                if (key == "shockThreshold") {
                    if (typeof value == "float" && value > 0.0 && value <= 16.0) {
                        _shockThr = value;
                    } else {
                        ::error("shockThreshold incorrect value (must be in [0;16] g)", "@{CLASS_NAME}");
                        shockSettIsCorr = false;
                        break;
                    }
                }
            } else {
                ::error("Incorrect shock condition settings", "@{CLASS_NAME}");
                shockSettIsCorr = false;
                break;
            }
        }

        if (_isFunction(shockCb) && shockSettIsCorr) {
            _shockCb = shockCb;
            _enShockDetect = true;
            // TODO: deal with the shock after initialization
            // accelerometer range determined by the value of shock threashold
            local range = _accel.setRange(_shockThr.tointeger());
            ::info(format("Accelerometer range +-%d g", range), "@{CLASS_NAME}");
            // TODO: Is it better to use inertial interrupt here?
            _accel.configureClickInterrupt(true, LIS3DH_SINGLE_CLICK, _shockThr);
            ::info("Shock detection enabled", "@{CLASS_NAME}");
        } else {
            _shockCb = null;
            _enShockDetect = false;
            _accel.configureClickInterrupt(false);
            ::info("Shock detection disabled", "@{CLASS_NAME}");
        }
    }

    /**
     * Enables or disables a one-time motion detection.
     * If enabled, the specified callback is called only once when the motion condition is detected,
     * after that the detection is automatically disabled and (if needed) should be explicitly re-enabled again.
     * @param {function} motionCb - Callback to be called once when the motion condition is detected.
     *        The callback has no parameters. If null or not a function, the motion detection is disabled.
     *        Otherwise, the motion detection is (re-)enabled for the provided motion condition.
     * @param {table} motionCnd - Table with the motion condition settings.
     *        Optional, all settings have defaults.
     *        The settings:
     *          "movementAccMax": {float}    - Movement acceleration maximum threshold, in g.
     *                                        Default: ACCEL_DEFAULT_MOV_MAX
     *          "movementAccMin": {float}    - Movement acceleration minimum threshold, in g.
     *                                        Default: ACCEL_DEFAULT_MOV_MIN
     *          "movementAccDur": {float}    - Duration of exceeding movement acceleration threshold, in seconds.
     *                                        Default: ACCEL_DEFAULT_MOV_DUR
     *          "motionTime": {float}  - Maximum time to determine motion detection after the initial movement, in seconds.
     *                                        Default: ACCEL_DEFAULT_MOTION_TIME
     *          "motionVelocity": {float} - Minimum instantaneous velocity  to determine motion detection condition, in meters per second.
     *                                        Default: ACCEL_DEFAULT_MOTION_VEL
     *          "motionDistance": {float} - Minimal movement distance to determine motion detection condition, in meters.
     *                                      If 0, distance is not calculated (not used for motion detection).
     *                                        Default: ACCEL_DEFAULT_MOTION_DIST
     */
    function detectMotion(motionCb, motionCnd = {}) {
        local motionSettIsCorr = true;
        _movementCurThr = ACCEL_DEFAULT_MOV_MIN;
        _movementAccMin = ACCEL_DEFAULT_MOV_MIN;
        _movementAccMax = ACCEL_DEFAULT_MOV_MAX;
        _movementAccDur = ACCEL_DEFAULT_MOV_DUR;
        _motionVelocity = ACCEL_DEFAULT_MOTION_VEL;
        _motionTime = ACCEL_DEFAULT_MOTION_TIME;
        _motionDistance = ACCEL_DEFAULT_MOTION_DIST;
        foreach (key, value in motionCnd) {
            if (typeof key == "string") {
                if (key == "movementAccMax") {
                    if (typeof value == "float" && value > 0) {
                        _movementAccMax = value;
                    } else {
                        ::error("movementAccMax incorrect value", "@{CLASS_NAME}");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "movementAccMin") {
                    if (typeof value == "float"  && value > 0) {
                        _movementAccMin = value;
                        _movementCurThr = value;
                    } else {
                        ::error("movementAccMin incorrect value", "@{CLASS_NAME}");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "movementAccDur") {
                    if (typeof value == "float"  && value > 0) {
                        _movementAccDur = value;
                    } else {
                        ::error("movementAccDur incorrect value", "@{CLASS_NAME}");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "motionTime") {
                    if (typeof value == "float"  && value > 0) {
                        _motionTime = value;
                    } else {
                        ::error("motionTime incorrect value", "@{CLASS_NAME}");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "motionVelocity") {
                    if (typeof value == "float"  && value >= 0) {
                        _motionVelocity = value;
                    } else {
                        ::error("motionVelocity incorrect value", "@{CLASS_NAME}");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "motionDistance") {
                    if (typeof value == "float"  && value >= 0) {
                        _motionDistance = value;
                    } else {
                        ::error("motionDistance incorrect value", "@{CLASS_NAME}");
                        motionSettIsCorr = false;
                        break;
                    }
                }
            } else {
                ::error("Incorrect motion condition settings", "@{CLASS_NAME}");
                motionSettIsCorr = false;
                break;
            }
        }

        if (_isFunction(motionCb) && motionSettIsCorr) {
            _mtnCb = motionCb;
            _enMtnDetect = true;
            _motionState = ACCEL_MOTION_STATE.WAITING;
            _accel.configureFifoInterrupts(false);
            _accel.configureInertialInterrupt(true,
                                              _movementCurThr,
                                              (_movementAccDur*ACCEL_DEFAULT_DATA_RATE).tointeger());
            ::info("Motion detection enabled", "@{CLASS_NAME}");
        } else {
            _mtnCb = null;
            _enMtnDetect = false;
            _motionState = ACCEL_MOTION_STATE.DISABLED;
            _positionCur.clear();
            _positionPrev.clear();
            _movementCurThr = _movementAccMin;
            _enMtnDetect = false;
            _accel.configureFifoInterrupts(false);
            _accel.configureInertialInterrupt(false);
            ::info("Motion detection disabled", "@{CLASS_NAME}");
        }
    }

    // ---------------- PRIVATE METHODS ---------------- //

    /**
     * Check object for callback function set method.
     * @param {function} f - Callback function.
     * @return {boolean} true if argument is function and not null.
     */
    function _isFunction(f) {
        return f && typeof f == "function";
    }

    /**
     * Enable/disable internal thermosensor.
     *
     * @param {boolean} enable - true if enable thermosensor.
     */
    function _switchTempSensor(enable) {
        // LIS3DH_TEMP_CFG_REG enables/disables temperature sensor
        _accel._setReg(LIS3DH_TEMP_CFG_REG, enable ? LIS2DH12_TEMP_EN : 0);

        local valReg4 = _accel._getReg(LIS3DH_CTRL_REG4);

        if (enable) {
            valReg4 = valReg4 | LIS2DH12_BDU;
        } else {
            valReg4 = valReg4 & ~LIS2DH12_BDU;
        }

        _accel._setReg(LIS3DH_CTRL_REG4, valReg4);
    }

    /**
     * Handler to check interrupt from accelerometer
     */
    function _checkInt() {
        const ACCEL_SHOCK_COOLDOWN = 1;

        if (_intPin.read() == 0)
            return;

        local intTable = _accel.getInterruptTable();

        if (intTable.singleClick) {
            ::debug("Shock interrupt", "@{CLASS_NAME}");
            _accel.configureClickInterrupt(false);
            if (_shockCb && _enShockDetect) {
                _shockCb();
            }
            imp.wakeup(ACCEL_SHOCK_COOLDOWN, function() {
                if (_enShockDetect) {
                    _accel.configureClickInterrupt(true, LIS3DH_SINGLE_CLICK, _shockThr);
                }
            }.bindenv(this));
        }

        if (intTable.int1) {
            _accel.configureInertialInterrupt(false);
            _accel.configureFifoInterrupts(true, false, ACCEL_DEFAULT_WTM);
            ledIndication && ledIndication.indicate(LI_EVENT_TYPE.MOVEMENT_DETECTED);
            if (_motionState == ACCEL_MOTION_STATE.WAITING) {
                _motionState = ACCEL_MOTION_STATE.CONFIRMING;
                _motionCurTime = time();
            }
            _accAverage();
            _removeOffset();
            _calcVelosityAndPosition();
            if (_motionState == ACCEL_MOTION_STATE.CONFIRMING) {
                _confirmMotion();
            }
            _checkZeroValueAcc();
        }

        if (_checkFIFOWtrm()) {
            _accAverage();
            _removeOffset();
            _calcVelosityAndPosition();
            if (_motionState == ACCEL_MOTION_STATE.CONFIRMING) {
                _confirmMotion();
            }
            _checkZeroValueAcc();
        }
        _accel.configureFifo(true, LIS3DH_FIFO_BYPASS_MODE);
        _accel.configureFifo(true, LIS3DH_FIFO_STREAM_TO_FIFO_MODE);
    }

    /**
     * Check FIFO watermark.
     * @return {boolean} true if watermark bit is set (for motion).
     */
    function _checkFIFOWtrm() {
        local res = false;
        local fifoSt = 0;
        try {
            fifoSt = _accel._getReg(LIS2DH12_FIFO_SRC_REG);
        } catch (e) {
            ::error("Error get FIFO state register", "@{CLASS_NAME}");
            fifoSt = 0;
        }

        if (fifoSt & LIS2DH12_FIFO_WTM) {
            res = true;
        }

        return res;
    }

    /**
     * Calculate average acceleration.
     */
    function _accAverage() {
        local stats = _accel.getFifoStats();

        _accCur.clear();

        for (local i = 0; i < stats.unread; i++) {
            local data = _accel.getAccel();

            foreach (key, val in data) {
                if (key == "error") {
                    ::error("Error get acceleration values", "@{CLASS_NAME}");
                    return;
                }
            }

            local acc = FloatVector(data.x, data.y, data.z);
            _accCur = _accCur + acc;
        }

        if (stats.unread > 0) {
            _accCur = _accCur / stats.unread.tofloat();
        }
    }

    /**
     * Remove offset from acceleration data
     * (Typical zero-g level offset accuracy for LIS2DH 40 mg).
     */
    function _removeOffset() {
        // acceleration |____/\_<- real acceleration______________________ACCEL_DISCR_WNDW_HIGH_THR
        //              |   /  \        /\    /\  <- noise
        //              |--/----\/\----/--\--/--\------------------------- time
        //              |__________\__/____\/_____________________________
        //              |           \/ <- real acceleration               ACCEL_DISCR_WNDW_LOW_THR
        if (_accCur._x < ACCEL_DISCR_WNDW_HIGH_THR && _accCur._x > ACCEL_DISCR_WNDW_LOW_THR) {
            _accCur._x = 0.0;
        }

        if (_accCur._y < ACCEL_DISCR_WNDW_HIGH_THR && _accCur._y > ACCEL_DISCR_WNDW_LOW_THR) {
            _accCur._y = 0.0;
        }

        if (_accCur._z < ACCEL_DISCR_WNDW_HIGH_THR && _accCur._z > ACCEL_DISCR_WNDW_LOW_THR) {
            _accCur._z = 0.0;
        }
    }

    /**
     * Calculate velocity and position.
     */
    function _calcVelosityAndPosition() {
        //  errors of integration are reduced with a first order approximation (Trapezoidal method)
        _velCur = (_accCur + _accPrev) / 2.0;
        // a |  __/|\  half the sum of the bases ((acur + aprev)*0.5) multiplied by the height (dt)
        //   | /|  | \___
        //   |/ |  |   | \
        //   |---------------------------------------- t
        //   |
        //   |   dt
        _velCur = _velCur*(ACCEL_G*ACCEL_DEFAULT_WTM.tofloat() / ACCEL_DEFAULT_DATA_RATE.tofloat());
        _velCur = _velPrev + _velCur;

        if (_motionDistance > 0) {
            _positionCur = (_velCur + _velPrev) / 2.0;
            _positionCur = _positionPrev + _positionCur;
        }
        _accPrev = _accCur;
        _velPrev = _velCur;
        _positionPrev = _positionCur;
    }

    /**
     * Check if motion condition(s) occured
     *
     */
    function _confirmMotion() {
        local vel = _velCur.length();
        local moving = _positionCur.length();

        local diffTm = time() - _motionCurTime;
        if (diffTm < _motionTime) {
            if (vel > _motionVelocity) {
                _thrVelExceeded = true;
            }
            if (_motionDistance > 0 && moving > _motionDistance) {
                _motionConfirmed();
            }
        } else {
            // motion condition: max(V(t)) > Vthr and V(Tmax) > 0 for t -> [0;Tmax]
            if (_thrVelExceeded && vel > 0) {
                _thrVelExceeded = false;
                _motionConfirmed();
                return;
            }
            // if motion not detected increase movement threshold (threshold -> [movMin;movMax])
            _motionState = ACCEL_MOTION_STATE.WAITING;
            _thrVelExceeded = false;
            if (_movementCurThr < _movementAccMax) {
                _movementCurThr += ACCEL_DEFAULT_MOV_STEP;
                if (_movementCurThr > _movementAccMax)
                    _movementCurThr = _movementAccMax;
            }
            ::debug(format("Motion is NOT confirmed. New movementCurThr %f g", _movementCurThr), "@{CLASS_NAME}")
            _positionCur.clear();
            _positionPrev.clear();
            _accel.configureFifoInterrupts(false);
            _accel.configureInertialInterrupt(true, _movementCurThr, (_movementAccDur*ACCEL_DEFAULT_DATA_RATE).tointeger());
        }
    }

    /**
     * Motion callback function execute and disable interrupts.
     */
    function _motionConfirmed() {
        ::info("Motion confirmed", "@{CLASS_NAME}");
        _motionState = ACCEL_MOTION_STATE.DISABLED;
        if (_mtnCb && _enMtnDetect) {
            // clear current and previous position for new motion detection
            _positionCur.clear();
            _positionPrev.clear();
            // reset movement threshold to minimum value
            _movementCurThr = _movementAccMin;
            _enMtnDetect = false;
            // disable all interrupts
            _accel.configureInertialInterrupt(false);
            _accel.configureFifoInterrupts(false);
            ::debug("Motion detection disabled", "@{CLASS_NAME}");
            _mtnCb();
        }
    }

    /**
     * Сheck for zero acceleration.
     */
    function _checkZeroValueAcc() {
        if (_accCur._x == 0.0) {
            if (_cntrAccLowX > 0)
                _cntrAccLowX--;
            else if (_cntrAccLowX == 0) {
                _cntrAccLowX = ACCEL_VELOCITY_RESET_CNTR;
                _velCur._x = 0.0;
                _velPrev._x = 0.0;
            }
        }

        if (_accCur._y == 0.0) {
            if (_cntrAccLowY > 0)
                _cntrAccLowY--;
            else if (_cntrAccLowY == 0) {
                _cntrAccLowY = ACCEL_VELOCITY_RESET_CNTR;
                _velCur._y = 0.0;
                _velPrev._y = 0.0;
            }
        }

        if (_accCur._z == 0.0) {
            if (_cntrAccLowZ > 0)
                _cntrAccLowZ--;
            else if (_cntrAccLowZ == 0) {
                _cntrAccLowZ = ACCEL_VELOCITY_RESET_CNTR;
                _velCur._z = 0.0;
                _velPrev._z = 0.0;
            }
        }
    }
}

@set CLASS_NAME = null // Reset the variable
