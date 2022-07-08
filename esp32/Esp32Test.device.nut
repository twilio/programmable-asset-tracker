// Simple test for communication with ESP32 module via AT interface:
// - request ESP32 firmware version (AT+GMR) periodically

// request period, in seconds
const VERSION_REQ_PERIOD = 300;

// new RX FIFO size
const RX_FIFO_SIZE = 200;

// UART settings
const DEFAULT_BAUDRATE = 115200;
const DEFAULT_BIT_IN_CHAR = 8;
const DAFAULT_STOP_BITS = 1;

// version information
res <- "";

class FlipFlop {
    _clkPin = null;
    _switchPin = null;

    constructor(clkPin, switchPin) {
        _clkPin = clkPin;
        _switchPin = switchPin;
    }

    function _get(key) {
        if (!(key in _switchPin)) {
            throw null;
        }

        // We want to clock the flip-flop after every change on the pin. This will trigger clocking even when the pin is being read.
        // But this shouldn't affect anything. Moreover, it's assumed that DIGITAL_OUT pins are read rarely.
        // To "attach" clocking to every pin's function, we return a wrapper-function that calls the requested original pin's
        // function and then clocks the flip-flop. This will make it transparent for the other components/modules.
        // All members of hardware.pin objects are functions. Hence we can always return a function here
        return function(...) {
            // Let's call the requested function with the arguments passed
            vargv.insert(0, _switchPin);
            // Also, we save the value returned by the original pin's function
            local res = _switchPin[key].acall(vargv);

            // Then we clock the flip-flop assuming that the default pin value is LOW (externally pulled-down)
            _clkPin.configure(DIGITAL_OUT, 1);
            _clkPin.disable();

            // Return the value returned by the original pin's function
            return res;
        };
    }
}

// callback on UART data receive
function loop() {
    local data = serial.read();
    // read until FIFO not empty and accumulate to res string
    while (data != -1) {
        res += data.tochar();
        data = serial.read();
    }
    if (res.len()) {
        // split to strings
        local resArr = split(res, "\r\n");
        foreach (el in resArr) {
            server.log(el);
        }
        res = "";
    }
}

function reqVers() {
    server.log("Send request");
    serial.write("AT+GMR\r\n");
    imp.wakeup(VERSION_REQ_PERIOD, reqVers);
}

// on 3.3V to board
enable3V <- FlipFlop(hardware.pinYD, hardware.pinS);
enable3V.configure(DIGITAL_OUT, 0);
imp.sleep(5);
enable3V.write(1);

// configure UART (imp006 mikroBUS)
serial <- hardware.uartABCD;
serial.setrxfifosize(RX_FIFO_SIZE);
serial.configure(DEFAULT_BAUDRATE, 
                 DEFAULT_BIT_IN_CHAR, 
                 PARITY_NONE, 
                 DAFAULT_STOP_BITS, 
                 NO_CTSRTS, 
                 loop);

// send version request
imp.wakeup(5, reqVers);