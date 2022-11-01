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

function getValFromTable(tbl, path, defaultVal = null) {
    local pathSplit = split(path, "/");
    local curValue = tbl;

    for (local i = 0; i < pathSplit.len(); i++) {
        if (typeof(curValue) == "table" && pathSplit[i] in curValue) {
            curValue = curValue[pathSplit[i]];
        } else {
            return defaultVal;
        }
    }

    return curValue;
}

function getValsFromTable(tbl, keys) {
    if (tbl == null) {
        return {};
    }

    local res = {};

    foreach (key in keys) {
        (key in tbl) && (res[key] <- tbl[key]);
    }

    return res;
}

// Returns null if the object passed has zero length
function nullEmpty(obj) {
    if (obj == null || obj.len() == 0) {
        return null;
    }

    return obj;
}

function mixTables(src, dst) {
    if (src == null) {
        return dst;
    }

    foreach (k, v in src) {
        dst[k] <- v;
    }

    return dst;
}

function deepEqual(value1, value2, level = 0) {
    if (level > 32) {
        throw "Possible cyclic reference";
    }

    if (value1 == value2) {
        return true;
    }

    local type1 = type(value1);
    local type2 = type(value2);

    if (type1 == "class" || type2 == "class") {
        throw "Unsupported type";
    }

    if (type1 != type2) {
        return false;
    }

    switch (type1) {
        case "table":
        case "array":
            if (value1.len() != value2.len()) {
                return false;
            }

            foreach (k, v in value1) {
                if (!(k in value2) || !deepEqual(v, value2[k], level + 1)) {
                    return false;
                }
            }

            return true;
        default:
            return false;
    }
}

function tableFullCopy(tbl) {
    // NOTE: This may be suboptimal. May need to be improved
    return Serializer.deserialize(Serializer.serialize(tbl));
}