export const unflatten = (data) => {
    // https://stackoverflow.com/questions/42694980/how-to-unflatten-a-javascript-object-in-a-daisy-chain-dot-notation-into-an-objec
    const result = {};
    for (const i in data) {
        const keys = i.split('.');
        keys.reduce(function (r, e, j) {
            return (r[e] || (r[e] = isNaN(Number(keys[j + 1])) ? (keys.length - 1 == j ? data[i] : {}) : []));
        }, result);
    }
    return result;
};
export const isArray = (array) => {
    return !!array && array.constructor === Array;
};
export const isObject = (object) => {
    return !!object && object.constructor === Object;
};
export const hasNesting = (thing) => {
    if (isObject(thing) && Object.keys(thing).length > 0) {
        return true;
    }
    if (isArray(thing) && thing.length > 0) {
        return true;
    }
    return false;
};
//# sourceMappingURL=utils.js.map