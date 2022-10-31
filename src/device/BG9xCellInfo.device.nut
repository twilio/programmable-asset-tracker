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

@set CLASS_NAME = "BG9xCellInfo" // Class name for logging

// Required BG96/95 AT Commands
enum AT_COMMAND {
    // Query the information of neighbour cells (Detailed information of base station)
    GET_QENG  = "AT+QENG=\"neighbourcell\"",
    // Query the information of serving cell (Detailed information of base station)
    GET_QENG_SERV_CELL  = "AT+QENG=\"servingcell\""
}

// Class to obtain cell towers info from BG96/95 modems.
// This code uses unofficial impOS features
// and is based on an unofficial example provided by Twilio
// Utilizes the following AT Commands:
// - QuecCell Commands:
//   - AT+QENG Switch on/off Engineering Mode
class BG9xCellInfo {

    /**
    * Get the network registration information from BG96/95
    *
    * @return {Table} The network registration information, or null on error.
    * Table fields include:
    * "radioType"                   - The mobile radio type: "gsm" or "lte"
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
        local data = {
            "radioType": null,
            "cellTowers": []
        };

        ::debug("Scanning cell towers..", "@{CLASS_NAME}");

        try {
            local qengCmdResp = _writeAndParseAT(AT_COMMAND.GET_QENG_SERV_CELL);
            if ("error" in qengCmdResp) {
                throw "AT+QENG serving cell command returned error: " + qengCmdResp.error;
            }

            local srvCellRadioType = _qengExtractRadioType(qengCmdResp.data);

            switch (srvCellRadioType) {
                // This type is used by both BG96/95 modem
                case "GSM":
                    data.radioType = "gsm";
                    // +QENG:
                    // "servingscell",<state>,"GSM",<mcc>,
                    // <mnc>,<lac>,<cellid>,<bsic>,<arfcn>,<band>,<rxlev>,<txp>,
                    // <rla>,<drx>,<c1>,<c2>,<gprs>,<tch>,<ts>,<ta>,<maio>,<hsn>,<rxlevsub>,
                    // <rxlevfull>,<rxqualsub>,<rxqualfull>,<voicecodec>
                    data.cellTowers.append(_qengExtractServingCellGSM(qengCmdResp.data));
                    // Neighbor towers
                    // +QENG:
                    // "neighbourcell","GSM",<mcc>,<mnc>,<lac>,<cellid>,<bsic>,<arfcn>,
                    // <rxlev>,<c1>,<c2>,<c31>,<c32>
                    qengCmdResp = _writeAndParseATMultiline(AT_COMMAND.GET_QENG);
                    if ("error" in qengCmdResp) {
                        ::error("AT+QENG command returned error: " + qengCmdResp.error, "@{CLASS_NAME}");
                    } else {
                        data.cellTowers.extend(_qengExtractTowersInfo(qengCmdResp.data, srvCellRadioType));
                    }
                    break;
                // These types are used by BG96 modem
                case "CAT-M":
                case "CAT-NB":
                case "LTE":
                // These types are used by BG95 modem
                case "eMTC":
                case "NBIoT":
                    data.radioType = "lte";
                    data.cellTowers.append(_qengExtractServingCellLTE(qengCmdResp.data));
                    // Neighbor towers parameters not correspond google API
                    // +QENG:
                    // "servingcell",<state>,"LTE",<is_tdd>,<mcc>,<mnc>,<cellid>,
                    // <pcid>,<earfcn>,<freq_band_ind>,
                    // <ul_bandwidth>,<d_bandwidth>,<tac>,<rsrp>,<rsrq>,<rssi>,<sinr>,<srxlev>
                    // +QENG: "neighbourcell intra”,"LTE",<earfcn>,<pcid>,<rsrq>,<rsrp>,<rssi>,<sinr>
                    // ,<srxlev>,<cell_resel_priority>,<s_non_intra_search>,<thresh_serving_low>,
                    // <s_intra_search>
                    // https://developers.google.com/maps/documentation/geolocation/overview#cell_tower_object
                    // Location is determined by one tower in this case
                    break;
                default:
                    throw "Unknown radio type: " + srvCellRadioType;
            }
        } catch (err) {
            ::error("Scanning cell towers error: " + err, "@{CLASS_NAME}");
            return null;
        }

        ::debug("Scanned items: " + data.len(), "@{CLASS_NAME}");

        return data;
    }

    // -------------------- PRIVATE METHODS -------------------- //

    /**
     * Send the specified AT Command, parse a response.
     * Return table with the parsed response.
     */
    function _writeAndParseAT(cmd) {
        const BG9XCI_FLUSH_TIMEOUT = 2;

        // This helps to avoid "Command in progress" error in some cases
        server.flush(BG9XCI_FLUSH_TIMEOUT);
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
     * Send the specified AT Command to the modem.
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
     * Extract mobile country and network codes, location area code,
     * cell ID, signal strength from dataLines parameter.
     * Return the info in array.
     */
    function _qengExtractTowersInfo(dataLines, checkRadioType) {
        try {
            local towers = [];

            foreach (line in dataLines) {
                local splitted = split(line, ",");

                if (splitted.len() < 9) {
                    continue;
                }

                local radioType = splitted[1];
                radioType = split(radioType, "\"")[0];

                if (radioType != checkRadioType) {
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

    /**
     * Extract radio type from the data parameter.
     * Return the info in a sring.
     */
    function _qengExtractRadioType(data) {
        // +QENG: "servingcell","NOCONN","GSM",250,99,DC51,B919,26,50,-,-73,255,255,0,38,38,1,-,-,-,-,-,-,-,-,-,"-"
        // +QENG: "servingcell","CONNECT","CAT-M","FDD",262,03,2FAA03,187,6200,20,3,3,2AFB,-105,-11,-76,10,-
        try {
            local splitted = split(data, ",");
            local radioType = splitted[2];
            radioType = split(radioType, "\"")[0];

            return radioType;
        } catch (err) {
            throw "Couldn't parse radio type (GET_QENG cmd): " + err;
        }
    }

     /**
     * Extract mobile country and network codes, location area code,
     * cell ID, signal strength from the data parameter. (GSM networks)
     * Return the info in a table.
     */
    function _qengExtractServingCellGSM(data) {
        // +QENG: "servingcell","NOCONN","GSM",250,99,DC51,B919,26,50,-,-73,255,255,0,38,38,1,-,-,-,-,-,-,-,-,-,"-"
        try {
            local splitted = split(data, ",");

            local mcc = splitted[3];
            local mnc = splitted[4];
            local lac = splitted[5];
            local ci = splitted[6];
            local ss = splitted[10];
            lac = utilities.hexStringToInteger(lac);
            ci = utilities.hexStringToInteger(ci);

            return {
                "mobileCountryCode" : mcc,
                "mobileNetworkCode" : mnc,
                "locationAreaCode" : lac,
                "cellId" : ci,
                "signalStrength" : ss
            };
        } catch (err) {
            throw "Couldn't parse serving cell (GET_QENG_SERV_CELL cmd): " + err;
        }
    }

    /**
     * Extract mobile country and network codes, location area code,
     * cell ID, signal strength from the data parameter. (LTE networks)
     * Return the info in a table.
     */
    function _qengExtractServingCellLTE(data) {
        // +QENG: "servingcell","CONNECT","CAT-M","FDD",262,03,2FAA03,187,6200,20,3,3,2AFB,-105,-11,-76,10,-
        try {
            local splitted = split(data, ",");

            local mcc = splitted[4];
            local mnc = splitted[5];
            local tac = splitted[12];
            local ci = splitted[6];
            local ss = splitted[15];
            tac = utilities.hexStringToInteger(tac);
            ci = utilities.hexStringToInteger(ci);

            return {
                "mobileCountryCode" : mcc,
                "mobileNetworkCode" : mnc,
                "locationAreaCode" : tac,
                "cellId" : ci,
                "signalStrength" : ss
            };
        } catch (err) {
            throw "Couldn't parse serving cell (GET_QENG_SERV_CELL cmd): " + err;
        }
    }
}

@set CLASS_NAME = null // Reset the variable
