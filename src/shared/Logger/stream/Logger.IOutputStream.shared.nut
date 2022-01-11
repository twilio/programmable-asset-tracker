/**
 * Logger output stream interface
 */
Logger.IOutputStream <- class {
    //  ------ PUBLIC FUNCTIONS TO OVERRIDE  ------- //
    function write(data) { throw "The Write method must be implemented in an inherited class" }
    function flush() { throw "The Flush method must be implemented in an inherited class" }
    function close() { throw "The Close method must be implemented in an inherited class" }
};

