import { makeUndoable } from 'components/activities/types';
import { List } from 'data/activities/model/list';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';
const PATH = '$..hints';
export const HINTS_BY_PART_PATH = (partId) => `$..parts[?(@.id==${partId})].hints`;
export const Hints = Object.assign(Object.assign({ path: PATH }, List(PATH)), { byPart: (model, partId) => Operations.apply(model, Operations.find(`$..parts[?(@.id==${partId})].hints`)), 
    // Native OLI activities split out hints into three types:
    // a. (0-1) Deer in headlights (re-explain the problem for students who don't understand the prompt)
    // b. (0-many) Cognitive hints (explain how to solve the problem)
    // c. (0-1) Bottom out hint (explain the answer)
    // These hints are saved in-order.
    getDeerInHeadlightsHint: (model, partId) => Hints.byPart(model, partId)[0], getCognitiveHints: (model, partId) => Hints.byPart(model, partId).slice(1, Hints.byPart(model, partId).length - 1), getBottomOutHint: (model, partId) => Hints.byPart(model, partId)[Hints.byPart(model, partId).length - 1], addOne(hint, partId) {
        return List(HINTS_BY_PART_PATH(partId)).addOne(hint);
    },
    addCognitiveHint(hint, partId) {
        return (model, _post) => {
            var _a;
            // new cognitive hints are inserted
            // right before the bottomOut hint at the end of the list
            const bottomOutIndex = Hints.byPart(model, partId).length - 1;
            (_a = model.authoring.parts.find((p) => p.id === partId)) === null || _a === void 0 ? void 0 : _a.hints.splice(bottomOutIndex, 0, hint);
        };
    },
    setContent(id, content) {
        return (model, _post) => {
            Hints.getOne(model, id).content = content;
        };
    },
    removeOne(id) {
        return (model, post) => {
            const hint = Hints.getOne(model, id);
            const index = Hints.getAll(model).findIndex((h) => h.id === id);
            List(PATH).removeOne(id)(model);
            post(makeUndoable('Removed a hint', [Operations.insert(PATH, clone(hint), index)]));
        };
    } });
//# sourceMappingURL=hints.js.map