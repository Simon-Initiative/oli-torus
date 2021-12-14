import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { Maybe } from 'tsmonad';
import { removeEmpty } from 'utils/common';
import guid from 'utils/guid';
// Activity delivery components have an `input` string which is the persisted value
// of a student's entry saved with `onSaveActivity` or submitted with
// `onSubmitActivity`. These functions convert between the `input` string and the
// `selection` which is a `ChoiceId[]` that is used directly by the delivery components.
export const studentInputToString = (studentInput) => studentInput.join(' ');
export const stringToStudentInput = (input) => input.split(' ').reduce((ids, id) => ids.concat([id]), []);
// An `ActivityState` only has an input if it has been saved or submitted.
// Each activity part may have an input.
export const safelySelectInputs = (activityState) => {
    const partInputs = activityState === null || activityState === void 0 ? void 0 : activityState.parts.filter((part) => { var _a; return !!((_a = part === null || part === void 0 ? void 0 : part.response) === null || _a === void 0 ? void 0 : _a.input); });
    if (!partInputs)
        return Maybe.nothing();
    return Maybe.maybe(activityState).lift((state) => state.parts.reduce((acc, partState) => {
        var _a;
        const input = (_a = partState.response) === null || _a === void 0 ? void 0 : _a.input;
        acc[String(partState.partId)] = typeof input === 'string' ? stringToStudentInput(input) : [];
        return acc;
    }, {}));
};
export const safelySelectStringInputs = (activityState) => {
    const partInputs = activityState === null || activityState === void 0 ? void 0 : activityState.parts.filter((part) => { var _a; return !!((_a = part === null || part === void 0 ? void 0 : part.response) === null || _a === void 0 ? void 0 : _a.input); });
    if (!partInputs)
        return Maybe.nothing();
    return Maybe.maybe(activityState).lift((state) => state.parts.reduce((acc, partState) => {
        var _a;
        const input = (_a = partState.response) === null || _a === void 0 ? void 0 : _a.input;
        acc[String(partState.partId)] = [input];
        return acc;
    }, {}));
};
export const initialPartInputs = (activityState, defaultPartInputs = { [DEFAULT_PART_ID]: [] }) => {
    const savedPartInputs = activityState === null || activityState === void 0 ? void 0 : activityState.parts.filter((part) => { var _a; return ((_a = part === null || part === void 0 ? void 0 : part.response) === null || _a === void 0 ? void 0 : _a.input) !== undefined; }).reduce((acc, part) => {
        acc[part.partId] = part.response.input;
        return acc;
    }, {});
    if (!savedPartInputs)
        return defaultPartInputs;
    return Object.entries(defaultPartInputs).reduce((acc, partInput) => {
        const [partId, defaultInput] = partInput;
        if (savedPartInputs[partId]) {
            acc[partId] = stringToStudentInput(savedPartInputs[partId]);
            return acc;
        }
        acc[partId] = defaultInput;
        return acc;
    }, {});
};
// Is an activity evaluation correct? This does not support partial credit.
export const isCorrect = (activityState) => activityState.score !== 0;
export const defaultActivityState = (model) => {
    const parts = model.authoring.parts.map((p) => ({
        attemptNumber: 1,
        attemptGuid: p.id,
        dateEvaluated: null,
        score: null,
        outOf: null,
        response: null,
        feedback: null,
        hints: [],
        hasMoreHints: removeEmpty(p.hints).length > 0,
        hasMoreAttempts: true,
        partId: p.id,
    }));
    return {
        attemptNumber: 1,
        attemptGuid: guid(),
        dateEvaluated: null,
        score: null,
        outOf: null,
        hasMoreAttempts: true,
        parts,
        hasMoreHints: false,
    };
};
//# sourceMappingURL=utils.js.map