
const ACCEL_USE_DEFAULT_ADDR = 0x32; // Accelerometr default IIC address
const ACCEL_USE_DEFAULT_DATA_RATE = 10; // Measurement rate (in Hz)
const ACCEL_USE_SHOCK_THR = 2; // Click (for shock detect) acceleration threshold (for LIS2DH12 register 0x3A)
const ACCEL_USE_SHOCK_TM_LIM = 5; // Click time limit (for LIS2DH12 register 0x3B)
const ACCEL_USE_SHOCK_LTN = 10; // Click time latency (for LIS2DH12 register 0x3C)
const ACCEL_USE_SHOCK_WND = 50; // Click time window (for LIS2DH12 register 0x3D)
const ACCEL_USE_FIFO_WTRM  = 5; // FIFO watermark value (for interrupt generation)

const LIS2DH12_CTRL_REG2 = 0x21; // HPF config
const LIS2DH12_REFERENCE = 0x26; // Reference acceleration/tilt value.
const LIS2DH12_HPF_AOI_INT1 = 0x01; // High-pass filter enabled for AOI function on Interrupt 1.
const LIS2DH12_FDS = 0x08; // Filtered data selection. Data from internal filter sent to output register and FIFO.
const LIS2DH12_FIFO_SRC_REG  = 0x2F; // FIFO state register.
const LIS2DH12_FIFO_WTM = 0x80; // set high when FIFO content exceeds watermark level.

// Accelerometer Common Interface Class.
// Implements common functions for motion detect.
class AccelerometerInterface {

    static VERSION = "0.2.0";

    // I2C is connected to
    _i2c  = null;

    // accelerometer I2C address 
    _addr = null;

    // accelerometer object
    _accel = null;

    // fifo data counter
    _dataCntr = null;

    /**
     * Constructor for Accelerometer Common Interface Class
     *
     * @param {object} i2c - The I2C object
     * @param {integer} addr - The I2C address of accelerometer
     */
    constructor(i2c, addr = ACCEL_USE_DEFAULT_ADDR) {
        _i2c  = i2c;
        _addr = addr;
        _i2c.configure(CLOCK_SPEED_400_KHZ);
    }

    /**
     * Create accelerometer object.
     *
     * This method must be called right after constructor.
     */
    function createAccel() {
        if (_accel == null) {
            _accel = LIS3DH(_i2c, _addr);
            ::debug("Create accelerometer object");
        }
    }

    /**
     * Configure accelerometer (set data rate, power mode etc.).
     */
    function configAccel() {
        if (_accel) {
            _accel.reset();
            _accel.setDataRate(ACCEL_USE_DEFAULT_DATA_RATE);
            _accel.setMode(LIS3DH_MODE_LOW_POWER);
        }
    }

    /**
     * Enable or disable accelerometer.
     * @param {boolean} en - true - enable, false - disable. 
     */
    function enableAccel(en) {
        if (_accel)
            _accel.enable(en);
    }

    /**
     * Configure interrupt settings of accelerometer.
     * Enable FIFO watermark and click interrupts.
     */
    function configAccelInterrupt() {
        if (_accel) {            
            _accel._setReg(LIS2DH12_CTRL_REG2, LIS2DH12_FDS | LIS2DH12_HPF_AOI_INT1);
            _accel._getReg(LIS2DH12_REFERENCE);
            _accel.getInterruptTable();
            _accel.configureClickInterrupt(true, LIS3DH_SINGLE_CLICK, ACCEL_USE_SHOCK_THR, ACCEL_USE_SHOCK_TM_LIM, ACCEL_USE_SHOCK_LTN, ACCEL_USE_SHOCK_WND);
            _accel.configureFifoInterrupts(true);
            _accel.configureInterruptLatching(false);
        }
    }

    /**
     * Get acceleration values.
     * @return {table} Acceleration values for x, y, z axis.
     * Includes the following key(string)-value pairs:
     * "x" : {float} - x axis acceleration
     * "y" : {float} - y axis acceleration
     * "z" : {float} - z axis acceleration
     */
    function getAccelData() {
        local data = null;
        if (_dataCntr > 0) {
            _dataCntr--;            
            data = _accel.getAccel();
        }
        
        return data;
    }

    /**
     * Configure MCU interrupt pin (conected to accelerometer).
     * @param {object} intPin - Hardware pin object.
     * @param {function} intCb - Callback to be called on pin event.
     *        intCb()
     */
    function configInterruptPin(intPin, intCb) {
        intPin.configure(DIGITAL_IN_WAKEUP, intCb);
    }

    /**
     * Configure accelerometer FIFO.
     */
    function configFIFOImpactCapt() {
        _accel.configureFifo(true, LIS3DH_FIFO_BYPASS_MODE);
        _accel.configureFifo(true, LIS3DH_FIFO_STREAM_TO_FIFO_MODE);
    }

    /**
     * Check FIFO watermark.
     * @return {boolean} true if watermark bit is set (for motion).
     */
    function checkIntMotionType() {
        local fifoSt = _accel._getReg(LIS2DH12_FIFO_SRC_REG);
        local res = false;

        if (fifoSt & LIS2DH12_FIFO_WTM) {
            local stats = _accel.getFifoStats();
            _dataCntr = stats.unread;
            res = true;
        }

        return res;
    }

    /**
     * Check interrupt table for shock detect.
     * @return {boolean} true if single click on (for shock).
     */
    function checkIntShockType() {
        local intTable = _accel.getInterruptTable();
        return intTable.singleClick;
    }
}
