import { getHint, getHints } from 'components/activities/common/hints/authoring/hintUtils';
import { noop } from 'components/activities/common/utils';
import { HasHints, Hint, PostUndoable, RichText } from 'components/activities/types';

export const HintActions = {
  addHint(hint: Hint) {
    return (model: HasHints, post: PostUndoable = noop) => {
      // new hints are always cognitive hints. they should be inserted
      // right before the bottomOut hint at the end of the list
      const bottomOutIndex = getHints(model).length - 1;
      getHints(model).splice(bottomOutIndex, 0, hint);
    };
  },

  editHint(id: string, content: RichText) {
    return (model: HasHints, post: PostUndoable = noop) => {
      getHint(model, id).content = content;
    };
  },

  removeHint(id: string) {
    return (model: HasHints, post: PostUndoable = noop) => {
      const hint = getHint(model, id);
      const index = getHints(model).findIndex((h) => h.id === id);
      model.authoring.parts[0].hints = getHints(model).filter((h) => h.id !== id);
      post({
        description: 'Removed a hint',
        operations: [
          {
            path: '$.authoring.parts[0].hints',
            index,
            item: JSON.parse(JSON.stringify(hint)),
          },
        ],
        type: 'Undoable',
      });
    };
  },
};
