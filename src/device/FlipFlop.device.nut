@set CLASS_NAME = "FlipFlop" // Class name for logging

// TODO: Comment
class FlipFlop {
    _clkPin = null;
    _switchPin = null;

    // TODO: Comment
    constructor(clkPin, switchPin) {
        _clkPin = clkPin;
        _switchPin = switchPin;
    }

    // TODO: Comment
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

@set CLASS_NAME = null // Reset the variable
