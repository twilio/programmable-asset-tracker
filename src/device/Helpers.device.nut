
// TODO: Comment
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

// TODO: Comment
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

// TODO: Comment
// Returns null if the object passed has zero length
function nullEmpty(obj) {
    if (obj == null || obj.len() == 0) {
        return null;
    }

    return obj;
}

// TODO: Comment
function mixTables(src, dst) {
    if (src == null) {
        return dst;
    }

    foreach (k, v in src) {
        dst[k] <- v;
    }

    return dst;
}

// TODO: Comment
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

// TODO: Comment
function tableFullCopy(tbl) {
    // TODO: This may be suboptimal. May need to be improved
    return Serializer.deserialize(Serializer.serialize(tbl));
}