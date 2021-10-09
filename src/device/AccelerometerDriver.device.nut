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
const ACCEL_DEFAULT_SHOCK_THR = 2;    // (for LIS2DH12 register 0x3A)

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

// Acceleration of gravity (m / s^2)
const ACCEL_G = 9.81;
// Default accelerometer's FIFO watermark
const ACCEL_DEFAULT_WTM = 15;
// Velocity zeroing counter (for stop motion)
const ACCEL_VELOCITY_RESET_CNTR = 2;
// Discrimination window applied low threshold
const ACCEL_DISCR_WNDW_LOW_THR = -0.05;
// Discrimination window applied high threshold
const ACCEL_DISCR_WNDW_HIGH_THR = 0.05;

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

    // current value of acceleration x axis
    _accXCur = null;

    // current value of acceleration y axis
    _accYCur = null;

    // current value of acceleration z axis
    _accZCur = null;

    // previous value of acceleration x axis
    _accXPrev = null;

    // previous value of acceleration y axis
    _accYPrev = null;

    // previous value of acceleration z axis
    _accZPrev = null;

    // current value of velocity x axis
    _velXCur = null;

    // current value of velocity y axis
    _velYCur = null;

    // current value of velocity z axis
    _velZCur = null;

    // previous value of velocity x axis
    _velXPrev = null;

    // previous value of velocity y axis
    _velYPrev = null;

    // previous value of velocity y axis
    _velZPrev = null;

    // current value of position x axis
    _positionXCur = null;

    // current value of position y axis
    _positionYCur = null;

    // current value of position z axis
    _positionZCur = null;

    // previous value of position x axis
    _positionXPrev = null;

    // previous value of position y axis
    _positionYPrev = null;

    // previous value of position z axis
    _positionZPrev = null;

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
        _velXCur = 0.0;
        _velYCur = 0.0;
        _velZCur = 0.0;

        _velXPrev = 0.0;
        _velYPrev = 0.0;
        _velZPrev = 0.0;

        _accXCur = 0.0;
        _accYCur = 0.0;
        _accZCur = 0.0;

        _accXPrev = 0.0;
        _accYPrev = 0.0;
        _accZPrev = 0.0;

        _positionXCur = 0.0;
        _positionYCur = 0.0;
        _positionZCur = 0.0;

        _positionXPrev = 0.0;
        _positionYPrev = 0.0;
        _positionZPrev = 0.0;

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
            ::debug("Shock detection enabled", "@{CLASS_NAME}");
        } else {
            _shockCb = null;
            _enShockDetect = false;
            _accel.configureClickInterrupt(false);
            ::debug("Shock detection disabled", "@{CLASS_NAME}");
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
            ::debug("Motion detection enabled", "@{CLASS_NAME}");
        } else {
            _mtnCb = null;
            _enMtnDetect = false;
            _motionState = ACCEL_MOTION_STATE_DISABLED;
            _positionXCur = 0;
            _positionYCur = 0;
            _positionZCur = 0;
            _positionXPrev = 0;
            _positionYPrev = 0;
            _positionZPrev = 0;
            _movementCurThr = _movementMin;
            _enMtnDetect = false;
            _accel.configureFifoInterrupts(false);
            _accel.configureInertialInterrupt(false);
            ::debug("Motion detection disabled", "@{CLASS_NAME}");
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

        _accXCur = 0;
        _accYCur = 0;
        _accZCur = 0;

        for (local i = 0; i < stats.unread; i++) {
            local data = _accel.getAccel();
            
            foreach (key, val in data) {
                if (key == "error") {
                    ::error("Error get acceleration values", "@{CLASS_NAME}");
                    return;
                }
            }

            _accXCur += data.x;
            _accYCur += data.y;
            _accZCur += data.z;
        }

        if (stats.unread > 0) {
            _accXCur /= stats.unread;
            _accYCur /= stats.unread;
            _accZCur /= stats.unread;
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
        if (_accXCur < ACCEL_DISCR_WNDW_HIGH_THR && _accXCur > ACCEL_DISCR_WNDW_LOW_THR) {
            _accXCur = 0;
        }

        if (_accYCur < ACCEL_DISCR_WNDW_HIGH_THR && _accYCur > ACCEL_DISCR_WNDW_LOW_THR) {
            _accYCur = 0;
        }

        if (_accZCur < ACCEL_DISCR_WNDW_HIGH_THR && _accZCur > ACCEL_DISCR_WNDW_LOW_THR) {
            _accZCur = 0;
        }
    }

    /**
     * Calculate velocity and position.     
     */
    function _calcVelosityAndPosition() {
        //  errors of integration are reduced with a first order approximation (Trapezoidal method)
        _velXCur = _velXPrev + _accXPrev + (_accXCur - _accXPrev) / 2.0;
        if (_motionDistance > 0) {
            _positionXCur = _positionXPrev + _velXPrev + (_velXCur - _velXPrev) / 2.0;
        }
        _accXPrev = _accXCur;
        _velXPrev = _velXCur;
        _positionXPrev = _positionXCur;

        _velYCur = _velYPrev + _accYPrev + (_accYCur - _accYPrev) / 2.0;
        if (_motionDistance > 0) {
            _positionYCur = _positionYPrev + _velYPrev + (_velYCur - _velYPrev) / 2.0;
        }
        _accYPrev = _accYCur;
        _velYPrev = _velYCur;
        _positionYPrev = _positionYCur;

        _velZCur = _velZPrev + _accZPrev + (_accZCur - _accZPrev) / 2.0;
        if (_motionDistance > 0) {
            _positionZCur = _positionZPrev + _velZPrev + (_velZCur - _velZPrev) / 2.0;
        }
        _accZPrev = _accZCur;
        _velZPrev = _velZCur;
        _positionZPrev = _positionZCur;
    }

    /**
     * Check if motion condition(s) occured
     * 
     */
    function _confirmMotion() {        
        local vel = _getVectorLength(_velXCur, _velYCur, _velZCur);
        local moving = _getVectorLength(_positionXCur, _positionYCur, _positionZCur);

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
            _positionXCur = 0;
            _positionYCur = 0;
            _positionZCur = 0;
            _positionXPrev = 0;
            _positionYPrev = 0;
            _positionZPrev = 0;
            _accel.configureFifoInterrupts(false);            
            _accel.configureInertialInterrupt(true, _movementCurThr, (_movementDur*ACCEL_DEFAULT_DATA_RATE).tointeger());            
        }
    }

    /**
     * Calculate vector length.
     * @param {float} x - current x coordinate.
     * @param {float} y - current y coordinate.
     * @param {float} z - current z coordinate.
     * 
     * @return {float} Current vector length.
     */
    function _getVectorLength(x, y, z) {
        return math.sqrt(x*x + y*y + z*z);
    }

    /**
     * Motion callback function execute and disable interrupts.
     */
    function _motionConfirmed() {
        ::debug("Motion confirmed", "@{CLASS_NAME}");
        _motionState = ACCEL_MOTION_STATE_DISABLED;
        if (_mtnCb && _enMtnDetect) {
            // clear current and previous position for new motion detection
            _positionXCur = 0;
            _positionYCur = 0;
            _positionZCur = 0;
            _positionXPrev = 0;
            _positionYPrev = 0;
            _positionZPrev = 0;
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
        if (_accXCur == 0) {
            if (_cntrAccLowX > 0)
                _cntrAccLowX--;
            else if (_cntrAccLowX == 0) {
                _cntrAccLowX = ACCEL_VELOCITY_RESET_CNTR;
                _velXCur = 0;
                _velXPrev = 0;
            }
        }

        if (_accYCur == 0) {
            if (_cntrAccLowY > 0)
                _cntrAccLowY--;
            else if (_cntrAccLowY == 0) {
                _cntrAccLowY = ACCEL_VELOCITY_RESET_CNTR;
                _velYCur = 0;
                _velYPrev = 0;
            }
        }

        if (_accZCur == 0) {
            if (_cntrAccLowZ > 0)
                _cntrAccLowZ--;
            else if (_cntrAccLowZ == 0) {
                _cntrAccLowZ = ACCEL_VELOCITY_RESET_CNTR;
                _velZCur = 0;
                _velZPrev = 0;                                
            }
        }
    }
}

@set CLASS_NAME = null // Reset the variable
