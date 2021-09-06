@set CLASS_NAME = "MotionMonitor" // Class name for logging

@include "AccelerometerInterface.device.nut"

const ACCEL_DISCR_WNDW_LOW_THR = -0.05; // Discrimination window applied low threshold
const ACCEL_DISCR_WNDW_HIGH_THR = 0.05; // Discrimination window applied high threshold

const MOTION_INIT = 1; // Initial state of motion detect FSM (finite state machine)
const MOTION_START = 2; // In motion state
const MOTION_STOP = 3; // Stop motion

const VELOCITY_THR = 0.1; // Start motion high velocity threshold
const VELOCITY_RESET_CNTR = 2; // Velocity zeroing counter (for stop motion)

// Motion Monitor class
// - detects motion start/stop
// - detects shocks
// Uses (extends) AccelerometerInterface class.
class MotionMonitor extends AccelerometerInterface {

    static VERSION = "0.2.0";

    // enable / disable motion detection
    _enMtnDetect = null;

    // enable / disable shock detection
    _enShockDetect = null;

    // motion detect callback function
    _mtnCb = null;

    // shock detect callback function
    _shockCb = null;

    // accelerometer int1 connected to this MCU pin (interrupt check)
    _intPin = null;

    // I2C address
    _addr = null;

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

    // counter for stop motion detect x axis
    _cntrAccLowX = null;

    // counter for stop motion detect y axis
    _cntrAccLowY = null;

    // counter for stop motion detect z axis
    _cntrAccLowZ = null;

    // initial state of motion FSM (start state -> motion state <-> not motion state)
    _motionState = null;

    // previous state motion FSM
    _motionPrevState = null;

    /**
     * Constructor for Motion Monitor Class
     *
     * @param {object} i2c - The I2C object
     * @param {object} intPin - Hardware pin object.
     * @param {integer} addr - The I2C address of accelerometer.
     * @param {boolean} enMtnDetect - Enable (true) or disable (false) motion detection.
     * @param {boolean} enShockDetect - Enable (true) or disable (false) shock detection.
     */
    constructor(i2c, intPin, addr = ACCEL_USE_DEFAULT_ADDR, enMtnDetect = false, enShockDetect = false) {
        _enMtnDetect = enMtnDetect;
        _enShockDetect = enShockDetect;
        _intPin = intPin;
        _addr = addr;

        _enMtnDetect = false;
        _enShockDetect = false;

        _velXCur = 0;
        _velYCur = 0;
        _velZCur = 0;

        _velXPrev = 0;
        _velYPrev = 0;
        _velZPrev = 0;

        _accXCur = 0;
        _accYCur = 0;
        _accZCur = 0;

        _accXPrev = 0;
        _accYPrev = 0;
        _accZPrev = 0;

        _cntrAccLowX = VELOCITY_RESET_CNTR;
        _cntrAccLowY = VELOCITY_RESET_CNTR;
        _cntrAccLowZ = VELOCITY_RESET_CNTR;

        _motionState = MOTION_INIT;
        _motionPrevState = MOTION_STOP;

        base.constructor(i2c, _addr);
        base.createAccel();
        base.configAccel();
        base.configFIFOImpactCapt();
        base.configInterruptPin(_intPin, _checkInt.bindenv(this));
        base.configAccelInterrupt();
        base.enableAccel(true);
    }

    /**
     * Set motion detect callback function .
     * @param {function} motionCb - Callback to be called on motion start or stop.
     *        motionCb(startStop), where 
     *        @param {boolean} startStop - true - start motion, false - stop motion.
     */
    function setMotionCb(motionCb) {
        if (_isFunction(motionCb)) {
            _mtnCb = motionCb;
        } else {
            ::error("Not a function cb:" + typeof motionCb);
        }
    }

    /**
     * Set shock detect callback function.
     * @param {function} shockCb - Callback to be called on shock detect.
     *        shockCb()
     */
    function setShockCb(shockCb) {
        if (_isFunction(shockCb))
            _shockCb = shockCb;
        else
            ::error("Not a function cb:" + typeof shockCb);
    }

    /**
     * Enable or disable motion detects (callback function execution).
     * @param {boolean} en - true - enable, false - disable.
     */
    function enableMotionDetection(en) {
        _enMtnDetect = en;        
    }

    /**
     * Enable or disable shock detects (callback function execution).
     * @param {boolean} en - true - enable, false - disable.
     */
    function enableShockDetection(en) {
        _enShockDetect = en;
    }

    // ---------------- PRIVATE METHODS ---------------- //

    /**
     * Check object for callback function set method.
     * @param {function} f - Callback function.
     * @return {boolean} true if argument is function.
     */
    function _isFunction(f) {
        return f && typeof f == "function";
    }

    /**
     * Remove offset from acceleration data (Typical zero-g level
     *  offset accuracy for LIS2DH 40 mg).
     */
    function _removeOffset() {

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
     * Get x axis velocity.
     * @return {float} Current x axis velocity.
     */
    function _getVelosityX() {
        _velXCur = _velXPrev + _accXPrev + (_accXCur - _accXPrev) / 2;
        _accXPrev = _accXCur;
        _velXPrev = _velXCur;

        return _velXCur;
    }

    /**
     * Get y axis velocity.
     * @return {float} Current y axis velocity.
     */
    function _getVelosityY() {        
        _velYCur = _velYPrev + _accYPrev + (_accYCur - _accYPrev) / 2;
        _accYPrev = _accYCur;
        _velYPrev = _velYCur;

        return _velYCur;
    }

    /**
     * Get z axis velocity.
     * @return {float} Current z axis velocity.
     */
    function _getVelosityZ() {        
        _velZCur = _velZPrev + _accZPrev + (_accZCur - _accZPrev) / 2;
        _accZPrev = _accZCur;
        _velZPrev = _velZCur;

        return _velZCur;
    }

    /**
     * Calculate velocity vector length.
     * @param {float} x - current x axis velocity.
     * @param {float} y - current y axis velocity.
     * @param {float} z - current z axis velocity.
     * 
     * @return {float} Current velocity vector length.
     */
    function _getVectorLength(x, y, z) {
        return math.sqrt(x*x + y*y + z*z);
    }

    /**
     * Motion detection.
     * @param {float} velX - current x axis velocity.
     * @param {float} velY - current y axis velocity.
     * @param {float} velZ - current z axis velocity.
     */
    function _getMotion(velX, velY, velZ) {
        local vel = _getVectorLength(velX, velY, velZ);
        ::debug(format("V %f", vel));
        if (vel > VELOCITY_THR) {
            if (_motionState == MOTION_STOP || _motionState == MOTION_INIT ) {
                _motionState = MOTION_START;
                if (_motionState != _motionPrevState) {
                    if (_mtnCb && _enMtnDetect) {
                        _mtnCb(true);
                    }
                }
            }            
        } 

        if (_accXCur == 0) {
            if (_cntrAccLowX > 0)
                _cntrAccLowX--;
            else if (_cntrAccLowX == 0) {
                _cntrAccLowX = VELOCITY_RESET_CNTR;
                _velXCur = 0;
                _velXPrev = 0;
            }
        }

        if (_accYCur == 0) {
            if (_cntrAccLowY > 0)
                _cntrAccLowY--;
            else if (_cntrAccLowY == 0) {
                _cntrAccLowY = VELOCITY_RESET_CNTR;
                _velYCur = 0;
                _velYPrev = 0;
            }
        }

        if (_accZCur == 0) {
            if (_cntrAccLowZ > 0)
                _cntrAccLowZ--;
            else if (_cntrAccLowZ == 0) {
                _cntrAccLowZ = VELOCITY_RESET_CNTR;
                _velZCur = 0;
                _velZPrev = 0;                                
            }
        }

        if (_velXCur == 0 && _velYCur == 0 && _velZCur == 0 && _velXPrev == 0 && _velYPrev == 0 && _velZPrev == 0) {
            if (_motionState == MOTION_START) {
                _motionState = MOTION_STOP;
                if (_motionState != _motionPrevState) {
                    if (_mtnCb && _enMtnDetect) {
                        _mtnCb(false);
                    }
                }
            }
        }

        _motionPrevState = _motionState;
    }

    /**
     * Check interrupt from accelerometer.
     */
    function _checkInt() {
        if (_intPin.read() == 0)
            return;

        if (base.checkIntShockType()) { 
            if (_shockCb && _enShockDetect) {
                _shockCb();
            }
        }
        
        if (base.checkIntMotionType()) { 
            local accData = null;
            local dataCnt = 0;
        
            _accXCur = 0;
            _accYCur = 0;
            _accZCur = 0;
            do {
                accData = base.getAccelData();
                if (accData != null) {
                    _accXCur += accData.x;
                    _accYCur += accData.y;
                    _accZCur += accData.z;
                    dataCnt++;
                }
            
            } while(accData != null);

            if (dataCnt > 0) {
                _accXCur /= dataCnt;
                _accYCur /= dataCnt;
                _accZCur /= dataCnt;
            }
            _removeOffset();
            _getMotion(_getVelosityX(), _getVelosityY(), _getVelosityZ());
        }

        base.configFIFOImpactCapt();
    }
}

@set CLASS_NAME = null // Reset the variable
