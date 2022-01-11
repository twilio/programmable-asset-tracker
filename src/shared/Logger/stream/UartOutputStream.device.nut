@include once __PATH__+"/Logger.IOutputStream.shared.nut"

/**
 * UART Output Stream.
 * Used for logging to UART and standard imp log in parallel
 */
class UartOutputStream extends Logger.IOutputStream {
    _uart = null;

    /**
     * Constructor for UART Output Stream
     *
     * @param {object} uart - The UART port object to be used for logging
     * @param {integer} [baudRate = 115200] - UART baud rate
     */
    constructor(uart, baudRate = 115200) {
        _uart = uart;
        _uart.configure(baudRate, 8, PARITY_NONE, 1, NO_CTSRTS | NO_RX);
    }

    /**
     * Write data to the output stream
     *
     * @param {any type} data - The data to log
     *
     * @return {integer} Send Error Code
     */
    function write(data) {
        local d = date();
        local ts = format("%04d-%02d-%02d %02d:%02d:%02d", d.year, d.month+1, d.day, d.hour, d.min, d.sec);
        _uart.write(ts + " " + data + "\n\r");
        return server.log(data);
    }
}
