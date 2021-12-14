import { Operations } from 'utils/pathOperations';
const ID_PATH = (id) => `[?(@.id==${id})]`;
export const List = (path) => ({
    getOne: (model, id) => Operations.apply(model, Operations.find(path + ID_PATH(id)))[0],
    getOneBy: (model, pred) => Operations.apply(model, Operations.find(path)).filter(pred)[0],
    getAll: (model) => Operations.apply(model, Operations.find(path)),
    getAllBy: (model, pred) => Operations.apply(model, Operations.find(path)).filter(pred),
    addOne(x) {
        return (model) => {
            Operations.apply(model, Operations.insert(path, x, -1));
        };
    },
    setOne(id, x) {
        return (model) => {
            Operations.apply(model, Operations.replace(path + ID_PATH(id), x));
        };
    },
    setAll(xs) {
        return (model) => {
            Operations.apply(model, Operations.replace(path, xs));
        };
    },
    removeOne(id) {
        return (model) => {
            Operations.apply(model, Operations.filter(path, `[?(@.id!=${id})]`));
        };
    },
});
//# sourceMappingURL=list.js.map