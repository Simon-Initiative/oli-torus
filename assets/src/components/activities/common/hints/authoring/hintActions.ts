import { getHint, getHints } from 'components/activities/common/hints/authoring/hintUtils';
import { HasHints, Hint, PostUndoable, RichText, makeUndoable } from 'components/activities/types';
import { clone } from 'utils/common';

export const HintActions = {
  addHint(hint: Hint) {
    return (model: HasHints, post: PostUndoable) => {
      // new hints are always cognitive hints. they should be inserted
      // right before the bottomOut hint at the end of the list
      const bottomOutIndex = getHints(model).length - 1;
      getHints(model).splice(bottomOutIndex, 0, hint);
    };
  },

  editHint(id: string, content: RichText) {
    return (model: HasHints, post: PostUndoable) => {
      getHint(model, id).content = content;
    };
  },

  removeHint(id: string, path: string) {
    return (model: HasHints, post: PostUndoable) => {
      const hint = getHint(model, id);
      const index = getHints(model).findIndex((h) => h.id === id);
      model.authoring.parts[0].hints = getHints(model).filter((h) => h.id !== id);

      post(
        makeUndoable('Removed a hint', [
          { type: 'InsertOperation', path: '$.authoring.parts[0].hints', index, item: clone(hint) },
        ]),
      );
    };
  },
};
