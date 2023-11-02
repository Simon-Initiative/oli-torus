import { Descendant } from 'slate';
import { Choice, PostUndoable } from 'components/activities/types';
import { List } from 'data/activities/model/list';
import { EditorType } from 'data/content/resource';
import { Operations } from 'utils/pathOperations';

const PATH = '$..choices';

export const Choices = {
  path: PATH,
  pathById: (id: string, path = PATH) => path + `[?(@.id=='${id}')]`,

  ...List<Choice>(PATH),

  setContent(id: string, content: Descendant[]) {
    return (model: any, _post: PostUndoable) => {
      Operations.apply(model, Operations.replace(`$..choices[?(@.id=='${id}')].content`, content));
    };
  },

  setTextDirection(id: string, textDirection: 'ltr' | 'rtl') {
    return (model: any, _post: PostUndoable) => {
      Operations.apply(
        model,
        Operations.setKey(`$..choices[?(@.id=='${id}')]`, 'textDirection', textDirection),
      );
    };
  },

  setEditor(id: string, editor: EditorType) {
    return (model: any, _post: PostUndoable) => {
      Operations.apply(model, Operations.setKey(`$..choices[?(@.id=='${id}')]`, 'editor', editor));
    };
  },
};

const ITEMS_PATH = '$..items';
export const Items = {
  path: ITEMS_PATH,

  ...List<Choice>(ITEMS_PATH),

  setContent(id: string, content: Descendant[]) {
    return (model: any, _post: PostUndoable) => {
      Operations.apply(model, Operations.replace(`$..items[?(@.id=='${id}')].content`, content));
    };
  },

  setEditor(id: string, editor: EditorType) {
    return (model: any, _post: PostUndoable) => {
      Operations.apply(model, Operations.setKey(`$..items[?(@.id=='${id}')]`, 'editor', editor));
    };
  },

  setTextDirection(id: string, textDirection: 'ltr' | 'rtl') {
    return (model: any, _post: PostUndoable) => {
      Operations.apply(
        model,
        Operations.setKey(`$..items[?(@.id=='${id}')]`, 'textDirection', textDirection),
      );
    };
  },
};
