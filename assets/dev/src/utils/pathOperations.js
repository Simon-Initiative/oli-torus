import jp from 'jsonpath';
// apply a series of transformations which may mutate the given json
export function applyAll(json, ops) {
    ops.forEach((op) => op && apply(json, op));
}
// apply a single operation and return the possibly transformed value
export function apply(json, op) {
    if (op.type === 'FindOperation') {
        // jsonpath returns a list of lists that match the path
        return jp.query(json, op.path).reduce((acc, result) => acc.concat(result), []);
    }
    return jp.apply(json, op.path, (result) => {
        if (op.type === 'InsertOperation') {
            // Impl of 'InsertOperation' is to insert at a specific index an item
            // into an array
            if (op.index === undefined || op.index === -1) {
                result.push(op.item);
            }
            else {
                result.splice(op.index, 0, op.item);
            }
            return result;
        }
        if (op.type === 'ReplaceOperation') {
            // Impl of 'ReplaceOperation' is simply returning the value of item
            // that will then replace the item matched via 'path'
            return op.item;
        }
        if (op.type === 'FilterOperation') {
            // This effectively replaces the results that match `op.path` with the results of `op.predicatePath`
            return jp.query(json, op.path + op.predicatePath);
        }
    });
}
export const find = (path) => ({
    type: 'FindOperation',
    path,
});
export const insert = (path, item, index) => ({
    type: 'InsertOperation',
    path,
    item,
    index,
});
export const replace = (path, item) => ({
    type: 'ReplaceOperation',
    path,
    item,
});
export const filter = (path, predicatePath) => ({
    type: 'FilterOperation',
    path,
    predicatePath,
});
export const Operations = {
    find,
    insert,
    replace,
    filter,
    apply,
    applyAll,
};
//# sourceMappingURL=pathOperations.js.map