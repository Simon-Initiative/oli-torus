import { List } from 'data/activities/model/list';
import { Operations } from 'utils/pathOperations';
const PATH = '$..choices';
export const Choices = Object.assign(Object.assign({ path: PATH, pathById: (id, path = PATH) => path + `[?(@.id==${id})]` }, List(PATH)), { setContent(id, content) {
        return (model, _post) => {
            Operations.apply(model, Operations.replace(`$..choices[?(@.id==${id})].content`, content));
        };
    } });
//# sourceMappingURL=choices.js.map