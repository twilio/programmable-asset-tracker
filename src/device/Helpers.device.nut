
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
