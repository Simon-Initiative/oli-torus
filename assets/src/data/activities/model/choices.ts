import { Choice, PostUndoable, RichText } from 'components/activities/types';
import { List } from 'data/activities/model/list';
import { Operations } from 'utils/pathOperations';

const PATH = '$..choices';

export const Choices = {
  path: PATH,
  pathById: (id: string, path = PATH) => path + `[?(@.id==${id})]`,

  ...List<Choice>(PATH),

  setContent(id: string, content: RichText) {
    return (model: any, _post: PostUndoable) => {
      Operations.apply(model, Operations.replace(`$..choices[?(@.id==${id})].content`, content));
    };
  },
};
