import { Choice, PostUndoable, RichText } from 'components/activities/types';
import { List } from 'data/activities/model/list';
import { Operations } from 'utils/pathOperations';

const PATH = '$..choices';

export const Choices = {
  path: PATH,
  pathById: (id: string, path = PATH) => path + `[?(@.id==${id})]`,

  ...List<Choice>(PATH),

  // getAll: (model: any, path = PATH): Choice[] => Operations.apply(model, Operations.find(path)),

  // getOne: (model: any, id: string, path = PATH): Choice =>
  //   Operations.apply(model, Operations.find(path + `[?(@.id==${id})]`))[0],

  // addOne(choice: Choice, path = PATH) {
  //   return (model: any, _post: PostUndoable) => {
  //     Operations.apply(model, Operations.insert(path, choice, -1));
  //   };
  // },
  setContent(id: string, content: RichText) {
    return (model: any, _post: PostUndoable) => {
      Operations.apply(model, Operations.replace(`$..choices[?(@.id==${id})].content`, content));
    };
  },

  // setAll(choices: Choice[], path = PATH) {
  //   return (model: any, _post: PostUndoable) => {
  //     Operations.apply(model, Operations.replace(path, choices));
  //   };
  // },

  // removeOne(id: string, path = PATH) {
  //   return (model: any, _post: PostUndoable) => {
  //     Operations.apply(model, Operations.filter(path, `[?(@.id!=${id})]`));
  //   };
  // },
};
