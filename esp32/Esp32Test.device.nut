
// request period
const VERSION_REQ_PERIOD = 60;

// UART settings
const DEFAULT_BAUDRATE = 115200;
const DEFAULT_BIT_IN_CHAR = 8;
const DAFAULT_STOP_BITS = 1;

// version information
res <- "";

// callback on UART data receive
function loop() {
    local data = serial.read();
    // read until FIFO not empty and accumulate to res string
    while (data != -1) {
        res += data.tochar();
        data = serial.read();
    }
}

// send request
function reqVers() {
    // version request write
    serial.write("AT+GMR\r\n");
    if (res.len()) {
        // split to strings
        local resArr = split(res, "\r\n");
        foreach (el in resArr) {
            server.log(el);
            imp.sleep(3);
        }
        // clear result string
        res = "";
    }
    imp.wakeup(VERSION_REQ_PERIOD, reqVers);
}

// enable 3.3V to board
enable3V <- hardware.pinXU;
enable3V.configure(DIGITAL_OUT, 1);

// configure UART (imp006 mikroBUS)
serial <- hardware.uartXEFGH;
serial.configure(DEFAULT_BAUDRATE, 
                 DEFAULT_BIT_IN_CHAR, 
                 PARITY_NONE, 
                 DAFAULT_STOP_BITS, 
                 NO_CTSRTS, 
                 loop);

// send version request (5 sec - delay after esp POR)
imp.wakeup(5, reqVers); 
