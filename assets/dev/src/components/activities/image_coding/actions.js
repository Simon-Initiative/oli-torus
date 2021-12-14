import { makeHint } from '../types';
import { Maybe } from 'tsmonad';
import { makeUndoable } from 'components/activities/types';
import { clone } from 'utils/common';
import { Operations } from 'utils/pathOperations';
import { toSimpleText } from 'components/editing/utils';
export class ICActions {
    static getById(slice, id) {
        return Maybe.maybe(slice.find((c) => c.id === id));
    }
    static editStem(content) {
        return (draftState, _post) => {
            draftState.stem.content = content;
            const previewText = toSimpleText(content);
            draftState.authoring.previewText = previewText;
        };
    }
    static editStarterCode(text) {
        return (draftState, _post) => {
            draftState.starterCode = text;
        };
    }
    static editSolutionCode(text) {
        return (draftState, _post) => {
            draftState.solutionCode = text;
        };
    }
    static editIsExample(value) {
        return (draftState, _post) => {
            draftState.isExample = value;
        };
    }
    static addResourceURL(value) {
        return (draftState, _post) => {
            if (draftState.resourceURLs.indexOf(value) === -1) {
                draftState.resourceURLs.push(value);
            }
        };
    }
    static removeResourceURL(value) {
        return (draftState, post) => {
            const index = draftState.resourceURLs.findIndex((url) => url === value);
            const item = draftState.resourceURLs[index];
            post(makeUndoable('Removed a file', [Operations.insert('$.resourceURLs', clone(item), index)]));
            draftState.resourceURLs = draftState.resourceURLs.filter((url) => url !== value);
        };
    }
    static editTolerance(value) {
        return (draftState, _post) => {
            draftState.tolerance = value;
        };
    }
    static editRegex(value) {
        return (draftState, _post) => {
            draftState.regex = value;
        };
    }
    static editFeedback(score, content) {
        return (draftState, _post) => {
            draftState.feedback[score].content = content;
        };
    }
    static addCognitiveHint() {
        return (draftState, _post) => {
            const newHint = makeHint('');
            // new hints are always cognitive hints. they should be inserted
            // right before the bottomOut hint at the end of the list
            const bottomOutIndex = draftState.authoring.parts[0].hints.length - 1;
            draftState.authoring.parts[0].hints.splice(bottomOutIndex, 0, newHint);
        };
    }
    static editHint(id, content) {
        return (draftState, _post) => {
            ICActions.getHint(draftState, id).lift((hint) => (hint.content = content));
        };
    }
    static removeHint(id) {
        return (draftState, post) => {
            const hint = draftState.authoring.parts[0].hints.find((h) => h.id === id);
            const index = draftState.authoring.parts[0].hints.findIndex((h) => h.id === id);
            post(makeUndoable('Removed a hint', [
                Operations.insert('$.authoring.parts[0].hints', clone(hint), index),
            ]));
            draftState.authoring.parts[0].hints = draftState.authoring.parts[0].hints.filter((h) => h.id !== id);
        };
    }
}
ICActions.getHint = (draftState, id) => ICActions.getById(draftState.authoring.parts[0].hints, id);
//# sourceMappingURL=actions.js.map