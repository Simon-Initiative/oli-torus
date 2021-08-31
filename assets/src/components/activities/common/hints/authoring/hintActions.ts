import { getHint, getHints, hintsByPart } from 'data/activities/model/hintUtils';
import { HasHints, Hint, PostUndoable, RichText, makeUndoable } from 'components/activities/types';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';

export const HintActions = {
  addHint(hint: Hint, partId: string) {
    return (model: HasHints, _post: PostUndoable) => {
      Operations.apply(model, Operations.insert(hintsByPart(partId), hint));
    };
  },

  addCognitiveHint(hint: Hint, partId: string) {
    return (model: HasHints, _post: PostUndoable) => {
      // new cognitive hints are inserted
      // right before the bottomOut hint at the end of the list
      const bottomOutIndex = getHints(model, partId).length - 1;
      getHints(model, partId).splice(bottomOutIndex, 0, hint);
    };
  },

  editHint(id: string, content: RichText, partId: string) {
    return (model: HasHints, _post: PostUndoable) => {
      getHint(model, id, partId).content = content;
    };
  },

  removeHint(id: string, path: string, partId: string) {
    return (model: HasHints, post: PostUndoable) => {
      const hint = getHint(model, id, partId);
      const index = getHints(model, partId).findIndex((h) => h.id === id);
      Operations.apply(model, Operations.filter(path, `[?(@.id!=${id})]`));

      post(makeUndoable('Removed a hint', [Operations.insert(path, clone(hint), index)]));
    };
  },
};
