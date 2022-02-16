@set CLASS_NAME = "BG96CellInfo" // Class name for logging

// Required BG96 AT Commands
enum AT_COMMAND {
    SET_CGREG = "AT+CGREG=2",  // Enable network registration and location information unsolicited result code
    GET_CGREG = "AT+CGREG?",   // Query the network registration status
    SET_COPS  = "AT+COPS=3,2", // Force an attempt to select and register the GSM/UMTS network operator
    GET_COPS  = "AT+COPS?",    // Query the current mode and selected operator
    GET_QENG  = "AT+QENG=\"neighbourcell\"" // Query the information of neighbour cells (Detailed information of base station)
}

// Class to obtain cell towers info from BG96 modem.
// This code uses unofficial impOS features
// and is based on an unofficial example provided by Twilio
// Utilizes the following AT Commands:
// - Network Service Commands:
//   - AT+CREG Network Registration Status
//   - AT+COPS Operator Selection
// - QuecCell Commands:
//   - AT+QENG Switch on/off Engineering Mode
class BG96CellInfo {

    /**
    * Get the network registration information from BG96
    *
    * @return {Table} The network registration information, or null on error.
    * Table fields include:
    * "radioType"                   - Always "gsm" string
    * "cellTowers"                  - Array of tables
    *     cellTowers[0]             - Table with information about the connected tower
    *         "locationAreaCode"    - Integer of the location area code  [0, 65535]
    *         "cellId"              - Integer cell ID
    *         "mobileCountryCode"   - Mobile country code string
    *         "mobileNetworkCode"   - Mobile network code string
    *     cellTowers[1 .. x]        - Table with information about the neighbor towers
    *                                 (optional)
    *         "locationAreaCode"    - Integer location area code [0, 65535]
    *         "cellId"              - Integer cell ID
    *         "mobileCountryCode"   - Mobile country code string
    *         "mobileNetworkCode"   - Mobile network code string
    *         "signalStrength"      - Signal strength string
    */
    function scanCellTowers() {
        local resp = null;
        local parsed = null;
        local tmp = null;
        local towers = [];

        try {
            local connectedTower = {};

            // connected tower
            resp = _writeAndParseAT(AT_COMMAND.SET_CGREG);
            resp = _writeAndParseAT(AT_COMMAND.GET_CGREG);

            if ("error" in resp) {
                ::error("AT+CGREG command returned error: " + resp.error, "@{CLASS_NAME}");
                return null;
            }

            if (!_cgregExtractTowerInfo(resp.data, connectedTower)) {
                ::info("No connected tower detected (by GCREG cmd)", "@{CLASS_NAME}");
                return null;
            }

            resp = _writeAndParseAT(AT_COMMAND.SET_COPS);
            resp = _writeAndParseAT(AT_COMMAND.GET_COPS);

            if ("error" in resp) {
                ::error("AT+COPS command returned error: " + resp.error, "@{CLASS_NAME}");
                return null;
            }

            if (!_copsExtractTowerInfo(resp.data, connectedTower)) {
                ::info("No connected tower detected (by COPS cmd)", "@{CLASS_NAME}");
                return null;
            }

            towers.append(connectedTower);

            // neighbor towers
            resp = _writeAndParseATMultiline(AT_COMMAND.GET_QENG);

            if ("error" in resp) {
                ::error("AT+QENG command returned error: " + resp.error, "@{CLASS_NAME}");
            } else {
                towers.extend(_qengExtractTowersInfo(resp.data));
            }
        } catch (err) {
            ::error("Scanning cell towers error: " + err, "@{CLASS_NAME}");
            return null;
        }

        local data = {};
        data.radioType <- "gsm";
        data.cellTowers <- towers;

        ::debug("Towers scanned: " + towers.len(), "@{CLASS_NAME}");

        return data;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Send the specified AT Command, parse a response.
     * Return table with the parsed response.
     */
    function _writeAndParseAT(cmd) {
        local resp = _writeATCommand(cmd);
        return _parseATResp(resp);
    }

    /**
     * Send the specified AT Command, parse a multiline response.
     * Return table with the parsed response.
     */
    function _writeAndParseATMultiline(cmd) {
        local resp = _writeATCommand(cmd);
        return _parseATRespMultiline(resp);
    }

    /**
     * Send the specified AT Command to BG96.
     * Return a string with response.
     *
     * This function uses unofficial impOS feature.
     *
     * This function blocks until the response is returned
     */
    function _writeATCommand(cmd) {
        return imp.setquirk(0x75636feb, cmd);
    }

    /**
     * Parse AT response and looks for "OK", error and response data.
     * Returns table that may contain fields: "raw", "error", "data", "success"
     */
    function _parseATResp(resp) {
        local parsed = {"raw" : resp};

        try {
            parsed.success <- (resp.find("OK") != null);

            local start = resp.find(":");
            (start != null) ? start+=2 : start = 0;

            local newLine = resp.find("\n");
            local end = (newLine != null) ? newLine : resp.len();

            local data = resp.slice(start, end);

            if (resp.find("Error") != null) {
                parsed.error <- data;
            } else {
                parsed.data  <- data;
            }
        } catch(e) {
            parsed.error <- "Error parsing AT response: " + e;
        }

        return parsed;
    }

    /**
     * Parse multiline AT response and looks for "OK", error and response data.
     * Returns table that may contain fields: "raw", "error",
     * "data" (array of string), success.
     */
    function _parseATRespMultiline(resp) {
        local parsed = {"raw" : resp};
        local data = [];
        local lines;

        try {
            parsed.success <- (resp.find("OK") != null);

            lines = split(resp, "\n");

            foreach (line in lines) {

                if (line == "OK") {
                    continue;
                }

                local start = line.find(":");
                (start != null) ? start +=2 : start = 0;

                local dataline = line.slice(start);
                data.push(dataline);

            }

            if (resp.find("Error") != null) {
                parsed.error <- data;
            } else {
                parsed.data  <- data;
            }
        } catch(e) {
            parsed.error <- "Error parsing AT response: " + e;
        }

        return parsed;
    }

    /**
     * Extract location area code and cell ID from dataStr parameter
     * and put it in dstTbl parameter.
     * Return true if the needed info found, false - otherwise.
     */
    function _cgregExtractTowerInfo(dataStr, dstTbl) {
        try {
            local splitted = split(dataStr, ",");

            if (splitted.len() >= 4) {
                local lac = splitted[2];
                lac = split(lac, "\"")[0];
                lac = utilities.hexStringToInteger(lac);

                local ci = splitted[3];
                ci = split(ci, "\"")[0];
                ci = utilities.hexStringToInteger(ci);

                dstTbl.locationAreaCode <- lac;
                dstTbl.cellId <- ci;

                return true;
            } else {
                return false;
            }
        } catch (err) {
            throw "Couldn't parse registration status (GET_CGREG cmd): " + err;
        }
    }

    /**
     * Extract mobile country and network codes from dataStr parameter
     * and put it in dstTbl parameter.
     * Return true if the needed info found, false - otherwise.
     */
    function _copsExtractTowerInfo(dataStr, dstTbl) {
        try {
            local splitted = split(dataStr, ",");

            if (splitted.len() >= 3) {
                local lai = splitted[2];
                lai = split(lai, "\"")[0];

                local mcc = lai.slice(0, 3);
                local mnc = lai.slice(3);

                dstTbl.mobileCountryCode <- mcc;
                dstTbl.mobileNetworkCode <- mnc;

                return true;
            } else {
                return false;
            }
        } catch (err) {
            throw "Couldn't parse operator selection (GET_COPS cmd): " + err;
        }
    }

    /**
     * Extract mobile country and network codes, location area code,
     * cell ID, signal strength from dataLines parameter.
     * Return the info in array.
     */
    function _qengExtractTowersInfo(dataLines) {
        try {
            local towers = [];

            foreach (line in dataLines) {
                local splitted = split(line, ",");

                if (splitted.len() < 9) {
                    continue;
                }

                local mcc = splitted[2];
                local mnc = splitted[3];
                local lac = splitted[4];
                local ci = splitted[5];
                local ss = splitted[8];

                lac = utilities.hexStringToInteger(lac);
                ci = utilities.hexStringToInteger(ci);

                towers.append({
                    "mobileCountryCode" : mcc,
                    "mobileNetworkCode" : mnc,
                    "locationAreaCode" : lac,
                    "cellId" : ci,
                    "signalStrength" : ss
                });
            }

            return towers;
        } catch (err) {
            throw "Couldn't parse neighbour cells (GET_QENG cmd): " + err;
        }
    }
}

@set CLASS_NAME = null // Reset the variable
