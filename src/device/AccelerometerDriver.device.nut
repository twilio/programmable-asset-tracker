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
const ACCEL_DEFAULT_DATA_RATE = 10;

// Defaults for shock detection:
// -----------------------------

// Acceleration threshold, in g
const ACCEL_DEFAULT_SHOCK_THR = 4;    // (for LIS2DH12 register 0x3A)

// Defaults for motion detection:
// ------------------------------

// Duration of exceeding the movement acceleration threshold, in seconds
const ACCEL_DEFAULT_MOV_DUR  = 0.5;
// Movement acceleration maximum threshold, in g
const ACCEL_DEFAULT_MOV_MAX = 0.3;
// Movement acceleration minimum threshold, in g
const ACCEL_DEFAULT_MOV_MIN = 0.1;
// Step change of movement acceleration threshold for bounce filtering, in g
const ACCEL_DEFAULT_MOV_STEP = 0.1;
// Default time to determine motion detection after the initial movement, in seconds.
const ACCEL_DEFAULT_MOTION_TIME = 20;
// Default instantaneous velocity to determine motion detection condition, in meters per second.
const ACCEL_DEFAULT_MOTION_VEL = 0.6;
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
const ACCEL_DEFAULT_WTM = 15;
// Velocity zeroing counter (for stop motion)
const ACCEL_VELOCITY_RESET_CNTR = 2;
// Discrimination window applied low threshold
const ACCEL_DISCR_WNDW_LOW_THR = -0.07;
// Discrimination window applied high threshold
const ACCEL_DISCR_WNDW_HIGH_THR = 0.07;

// States of the motion detection - FSM (finite state machine):
// Motion detection is disabled (initial state; motion detection is disabled automatically after motion is detected)
const ACCEL_MOTION_STATE_DISABLED = 1;
// Motion detection is enabled, waiting for initial movement detection
const ACCEL_MOTION_STATE_WAITING = 2;
// Motion is being confirmed after initial movement is detected
const ACCEL_MOTION_STATE_CONFIRMING = 3;

const LIS2DH12_CTRL_REG2 = 0x21; // HPF config
const LIS2DH12_REFERENCE = 0x26; // Reference acceleration/tilt value.
const LIS2DH12_HPF_AOI_INT1 = 0x01; // High-pass filter enabled for AOI function on Interrupt 1.
const LIS2DH12_FDS = 0x08; // Filtered data selection. Data from internal filter sent to output register and FIFO.
const LIS2DH12_FIFO_SRC_REG  = 0x2F; // FIFO state register.
const LIS2DH12_FIFO_WTM = 0x80; // Set high when FIFO content exceeds watermark level.

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

    // accelerometer I2C address
    _addr = null;

    // I2C is connected to
    _i2c  = null;

    // accelerometer object
    _accel = null;

    // shock threshold value
    _shockThr = null

    // duration of exceeding the movement acceleration threshold
    _movementDur = null;

    // current movement acceleration threshold
    _movementCurThr = null;

    // maximum value of acceleration threshold for bounce filtering
    _movementMax = null;

    // minimum value of acceleration threshold for bounce filtering
    _movementMin = null;

    // maximum time to determine motion detection after the initial movement
    _motionTimeout = null;

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
        _movementMin = ACCEL_DEFAULT_MOV_MIN;
        _movementMax = ACCEL_DEFAULT_MOV_MAX;
        _movementDur = ACCEL_DEFAULT_MOV_DUR;
        _motionCurTime = time();
        _motionVelocity = ACCEL_DEFAULT_MOTION_VEL;
        _motionVelocity /= ACCEL_G;
        _motionTimeout = ACCEL_DEFAULT_MOTION_TIME;
        _motionDistance = ACCEL_DEFAULT_MOTION_DIST;
        _motionDistance /= ACCEL_G;

        _velCur = FloatVector();
        _velPrev = FloatVector();
        _accCur = FloatVector();
        _accPrev = FloatVector();
        _positionCur = FloatVector();
        _positionPrev = FloatVector();

        _cntrAccLowX = ACCEL_VELOCITY_RESET_CNTR;
        _cntrAccLowY = ACCEL_VELOCITY_RESET_CNTR;
        _cntrAccLowZ = ACCEL_VELOCITY_RESET_CNTR;

        _motionState = ACCEL_MOTION_STATE_DISABLED;

        _i2c = i2c;
        _addr = addr;
        _intPin = intPin;

        try {
            _i2c.configure(CLOCK_SPEED_400_KHZ);
            _accel = LIS3DH(_i2c, _addr);
            _accel.reset();
            local range = _accel.setRange(ACCEL_RANGE);
            local rate = _accel.setDataRate(ACCEL_DEFAULT_DATA_RATE);
            ::debug(format("Accelerometer rate %d Hz", rate), "@{CLASS_NAME}");
            _accel.setMode(LIS3DH_MODE_LOW_POWER);
            _accel.enable(true);
            _accel.configureFifo(true, LIS3DH_FIFO_BYPASS_MODE);
            _accel.configureFifo(true, LIS3DH_FIFO_STREAM_TO_FIFO_MODE);
            _accel._setReg(LIS2DH12_CTRL_REG2, LIS2DH12_FDS | LIS2DH12_HPF_AOI_INT1);
            _accel._getReg(LIS2DH12_REFERENCE);
            _accel.getInterruptTable();
            _accel.configureInterruptLatching(false);
            _intPin.configure(DIGITAL_IN_WAKEUP, _checkInt.bindenv(this));
            ::debug("Accelerometer configured", "@{CLASS_NAME}");
        } catch (e) {
            throw "Accelerometer configuration error: " + e;
        }
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
                    if (typeof value == "float" && value > 0.0) {
                        _shockThr = value;
                    } else {
                        ::error("shockThreshold incorrect value", "@{CLASS_NAME}");
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
     * after that the detection is automatically disabled and
     * (if needed) should be explicitly re-enabled again.
     * @param {function} motionCb - Callback to be called once when the motion condition is detected.
     *        The callback has no parameters. If null or not a function, the motion detection is disabled.
     *        Otherwise, the motion detection is (re-)enabled for the provided motion condition.
     * @param {table} motionCnd - Table with the motion condition settings.
     *        Optional, all settings have defaults.
     *        The settings:
     *          "movementMax": {float}    - Movement acceleration maximum threshold, in g.
     *                                        Default: ACCEL_DEFAULT_MOV_MAX
     *          "movementMin": {float}    - Movement acceleration minimum threshold, in g.
     *                                        Default: ACCEL_DEFAULT_MOV_MIN
     *          "movementDur": {float}    - Duration of exceeding movement acceleration threshold, in seconds.
     *                                        Default: ACCEL_DEFAULT_MOV_DUR
     *          "motionTimeout": {float}  - Maximum time to determine motion detection after the initial movement, in seconds.
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
        _movementMin = ACCEL_DEFAULT_MOV_MIN;
        _movementMax = ACCEL_DEFAULT_MOV_MAX;
        _movementDur = ACCEL_DEFAULT_MOV_DUR;
        _motionVelocity = ACCEL_DEFAULT_MOTION_VEL;
        _motionVelocity /= ACCEL_G;
        _motionTimeout = ACCEL_DEFAULT_MOTION_TIME;
        _motionDistance = ACCEL_DEFAULT_MOTION_DIST;
        _motionDistance /= ACCEL_G;
        foreach (key, value in motionCnd) {
            if (typeof key == "string") {
                if (key == "movementMax") {
                    if (typeof value == "float" && value > 0) {
                        _movementMax = value;
                    } else {
                        ::error("movementMax incorrect value", "@{CLASS_NAME}");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "movementMin") {
                    if (typeof value == "float"  && value > 0) {
                        _movementMin = value;
                        _movementCurThr = value;
                    } else {
                        ::error("movementMin incorrect value", "@{CLASS_NAME}");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "movementDur") {
                    if (typeof value == "float"  && value > 0) {
                        _movementDur = value;
                    } else {
                        ::error("movementDur incorrect value", "@{CLASS_NAME}");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "motionTimeout") {
                    if (typeof value == "float"  && value > 0) {
                        _motionTimeout = value;
                    } else {
                        ::error("motionTimeout incorrect value", "@{CLASS_NAME}");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "motionVelocity") {
                    if (typeof value == "float"  && value >= 0) {
                        _motionVelocity = value;
                        _motionVelocity /= ACCEL_G;
                    } else {
                        ::error("motionVelocity incorrect value", "@{CLASS_NAME}");
                        motionSettIsCorr = false;
                        break;
                    }
                }

                if (key == "motionDistance") {
                    if (typeof value == "float"  && value >= 0) {
                        _motionDistance = value;
                        _motionDistance /= ACCEL_G;
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
            _motionState = ACCEL_MOTION_STATE_WAITING;
            _accel.configureFifoInterrupts(false);
            _accel.configureInertialInterrupt(true, _movementCurThr, (_movementDur*ACCEL_DEFAULT_DATA_RATE).tointeger());
            ::info("Motion detection enabled", "@{CLASS_NAME}");
        } else {
            _mtnCb = null;
            _enMtnDetect = false;
            _motionState = ACCEL_MOTION_STATE_DISABLED;
            _positionCur.clear();
            _positionPrev.clear();
            _movementCurThr = _movementMin;
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
     * Handler to check interrupt from accelerometer
     */
    function _checkInt() {
        if (_intPin.read() == 0)
            return;

        local intTable = _accel.getInterruptTable();

        if (intTable.singleClick) {
            ::debug("Shock interrupt", "@{CLASS_NAME}");
            if (_shockCb && _enShockDetect) {
                _shockCb();
            }
        }

        if (intTable.int1) {
            ::debug("Movement interrupt", "@{CLASS_NAME}");
            _accel.configureInertialInterrupt(false);
            _accel.configureFifoInterrupts(true, false, ACCEL_DEFAULT_WTM);
            if (_motionState == ACCEL_MOTION_STATE_WAITING) {
                _motionState = ACCEL_MOTION_STATE_CONFIRMING;
                _motionCurTime = time();
            }
            _accAverage();
            _removeOffset();
            _calcVelosityAndPosition();
            if (_motionState == ACCEL_MOTION_STATE_CONFIRMING) {
                _confirmMotion();
            }
            _checkZeroValueAcc();
        }

        if (_checkFIFOWtrm()) {
            ::debug("FIFO watermark", "@{CLASS_NAME}");
            _accAverage();
            _removeOffset();
            _calcVelosityAndPosition();
            if (_motionState == ACCEL_MOTION_STATE_CONFIRMING) {
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
        _velCur = _velPrev + _accPrev + (_accCur - _accPrev) / 2.0;
        if (_motionDistance > 0) {
            _positionCur = _positionPrev + _velPrev + (_velCur - _velPrev) / 2.0;
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

        ::debug(format("V %f m/s, S %f m", vel*ACCEL_G, moving*ACCEL_G), "@{CLASS_NAME}");
        local diffTm = time() - _motionCurTime;
        if (diffTm < _motionTimeout) {
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
            _motionState = ACCEL_MOTION_STATE_WAITING;
            _thrVelExceeded = false;
            if (_movementCurThr < _movementMax) {
                _movementCurThr += ACCEL_DEFAULT_MOV_STEP;
                if (_movementCurThr > _movementMax)
                    _movementCurThr = _movementMax;
            }
            ::debug(format("Motion is NOT confirmed. New movementCurThr %f g", _movementCurThr), "@{CLASS_NAME}")
            _positionCur.clear();
            _positionPrev.clear();
            _accel.configureFifoInterrupts(false);
            _accel.configureInertialInterrupt(true, _movementCurThr, (_movementDur*ACCEL_DEFAULT_DATA_RATE).tointeger());
        }
    }

    /**
     * Motion callback function execute and disable interrupts.
     */
    function _motionConfirmed() {
        ::info("Motion confirmed", "@{CLASS_NAME}");
        _motionState = ACCEL_MOTION_STATE_DISABLED;
        if (_mtnCb && _enMtnDetect) {
            // clear current and previous position for new motion detection
            _positionCur.clear();
            _positionPrev.clear();
            // reset movement threshold to minimum value
            _movementCurThr = _movementMin;
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
