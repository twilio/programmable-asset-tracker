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
