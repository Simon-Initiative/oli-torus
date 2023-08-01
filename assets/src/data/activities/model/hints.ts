import { HasHints, Hint, PostUndoable, RichText, makeUndoable } from 'components/activities/types';
import { List } from 'data/activities/model/list';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';

const PATH = '$..hints';

interface Hints extends Omit<List<Hint>, 'addOne' | 'removeOne'> {
  path: string;
  byPart: (model: HasHints, partId: string) => Hint[];
  addOne: (hint: Hint, partId: string) => (model: any, post: PostUndoable) => void;
  getDeerInHeadlightsHint: (model: HasHints, partId: string) => Hint;
  getCognitiveHints: (model: HasHints, partId: string) => Hint[];
  getBottomOutHint: (model: HasHints, partId: string) => Hint;
  addCognitiveHint(hint: Hint, partId: string): (model: HasHints, _post: PostUndoable) => void;
  setContent(id: string, content: RichText): (model: HasHints, _post: PostUndoable) => void;
  removeOne: (id: string, partId: string) => (model: any, post: PostUndoable) => void;
}

export const HINTS_BY_PART_PATH = (partId: string) => `$..parts[?(@.id=='${partId}')].hints`;

export const Hints: Hints = {
  path: PATH,
  ...List<Hint>(PATH),

  byPart: (model, partId) =>
    Operations.apply(model, Operations.find(`$..parts[?(@.id=='${partId}')].hints`)),

  // Native OLI activities split out hints into three types:
  // a. (0-1) Deer in headlights (re-explain the problem for students who don't understand the prompt)
  // b. (0-many) Cognitive hints (explain how to solve the problem)
  // c. (0-1) Bottom out hint (explain the answer)
  // These hints are saved in-order.
  getDeerInHeadlightsHint: (model: HasHints, partId: string) => Hints.byPart(model, partId)[0],
  getCognitiveHints: (model: HasHints, partId: string) =>
    Hints.byPart(model, partId).slice(1, Hints.byPart(model, partId).length - 1),
  getBottomOutHint: (model: HasHints, partId: string) =>
    Hints.byPart(model, partId)[Hints.byPart(model, partId).length - 1],

  addOne(hint: Hint, partId: string) {
    return List<Hint>(HINTS_BY_PART_PATH(partId)).addOne(hint);
  },

  addCognitiveHint(hint: Hint, partId: string) {
    return (model: HasHints, _post: PostUndoable) => {
      // new cognitive hints are inserted
      // right before the bottomOut hint at the end of the list
      const bottomOutIndex = Hints.byPart(model, partId).length - 1;
      model.authoring.parts.find((p) => p.id === partId)?.hints.splice(bottomOutIndex, 0, hint);
    };
  },

  setContent(id: string, content: RichText) {
    return (model: HasHints, _post: PostUndoable) => {
      Hints.getOne(model, id).content = content;
    };
  },

  removeOne(id: string, partId: string) {
    return (model: HasHints, post: PostUndoable) => {
      const index = Hints.byPart(model, partId).findIndex((h) => h.id === id);
      const hint = Hints.byPart(model, partId)[index];

      List<Hint>(HINTS_BY_PART_PATH(partId)).removeOne(id)(model);
      post(
        makeUndoable('Removed a hint', [
          Operations.insert(HINTS_BY_PART_PATH(partId), clone(hint), index),
        ]),
      );
    };
  },
};
