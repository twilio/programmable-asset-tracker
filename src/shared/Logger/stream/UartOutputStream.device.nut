// MIT License

// Copyright (C) 2022, Twilio, Inc. <help@twilio.com>

// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
// of the Software, and to permit persons to whom the Software is furnished to do
// so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

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
