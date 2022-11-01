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

@if LOGGER_STORAGE_TYPE == "ram"
@include once __PATH__+"/RamLoggerStorage.device.nut"

Logger.setStorage(
    RamLoggerStorage(@{LOGGER_RAM_STG_MAX_ITEMS})
);
@elseif LOGGER_STORAGE_TYPE == "flash"
@include once __PATH__+"/SpiFlashLoggerStorage.device.nut"

Logger.setStorage(
    SpiFlashLoggerStorage(
        @{LOGGER_FLASH_STG_START_ADDRESS},
        @{LOGGER_FLASH_STG_END_ADDRESS},
        null,
        @{LOGGER_FLASH_STG_FORCE_ERASE}
    )
);
@endif

@if LOGGER_STORAGE_ENABLE == "true" && LOGGER_STORAGE_LEVEL && (LOGGER_STORAGE_TYPE == "ram" || LOGGER_STORAGE_TYPE == "flash")
Logger.setLogStorageCfg(@{LOGGER_STORAGE_ENABLE}, "@{LOGGER_STORAGE_LEVEL}");
@endif
