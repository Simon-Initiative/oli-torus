export function registerCreationFunc(manifest, fn) {
    if (window.oliCreationFuncs === undefined) {
        window.oliCreationFuncs = {};
    }
    window.oliCreationFuncs[manifest.id] = fn;
}
export function invokeCreationFunc(id, context) {
    if (window.oliCreationFuncs !== undefined) {
        const fn = window.oliCreationFuncs[id];
        if (typeof fn === 'function') {
            return fn.apply(undefined, [context]);
        }
    }
    return Promise.reject('could not invoke creation function for ' + id);
}
//# sourceMappingURL=creation.js.map