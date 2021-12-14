var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { createSlice } from '@reduxjs/toolkit';
import { studentInputToString } from 'data/activities/utils';
import { Maybe } from 'tsmonad';
export const activityDeliverySlice = createSlice({
    name: 'ActivityDelivery',
    initialState: {},
    reducers: {
        activitySubmissionReceived(state, action) {
            if (action.payload.actions.length > 0) {
                const { score, out_of } = action.payload.actions.reduce((acc, action) => ({
                    score: acc.score + action.score,
                    out_of: acc.out_of + action.out_of,
                }), {
                    score: 0,
                    out_of: 0,
                });
                state.attemptState = Object.assign(Object.assign({}, state.attemptState), { score, outOf: out_of, parts: state.attemptState.parts.map((part) => {
                        const feedbackAction = action.payload.actions.find((action) => action.attempt_guid === part.attemptGuid);
                        if (!feedbackAction)
                            return part;
                        return Object.assign(part, {
                            score: feedbackAction.score,
                            outOf: feedbackAction.out_of,
                            feedback: feedbackAction.feedback,
                            error: feedbackAction.error,
                        });
                    }) });
            }
        },
        initializePartState(state, action) {
            state.partState = action.payload.parts.reduce((acc, partState) => {
                acc[String(partState.partId)] = { studentInput: [], hintsShown: [], hasMoreHints: false };
                return acc;
            }, {});
        },
        setPartInputs(state, action) {
            Object.entries(action.payload).forEach(([partId, studentInput]) => Maybe.maybe(state.partState[partId]).lift((partState) => (partState.studentInput = studentInput)));
        },
        setStudentInputForPart(state, action) {
            Maybe.maybe(state.partState[action.payload.partId]).lift((partState) => (partState.studentInput = action.payload.studentInput));
        },
        setAttemptState(state, action) {
            state.attemptState = action.payload;
        },
        updateChoiceSelectionMultiple(state, action) {
            const { partId, selection } = action.payload;
            Maybe.maybe(state.partState[partId]).lift((partState) => (partState.studentInput = partState.studentInput.find((choiceId) => choiceId === selection)
                ? partState.studentInput.filter((id) => id !== selection)
                : partState.studentInput.concat(selection)));
        },
        setHintsShownForPart(state, action) {
            Maybe.maybe(state.partState[action.payload.partId]).lift((partState) => (partState.hintsShown = action.payload.hintsShown));
        },
        showHintForPart(state, action) {
            Maybe.maybe(state.partState[action.payload.partId]).lift((partState) => partState.hintsShown.push(action.payload.hint));
        },
        setHasMoreHintsForPart(state, action) {
            Maybe.maybe(state.partState[action.payload.partId]).lift((partState) => (partState.hasMoreHints = action.payload.hasMoreHints));
        },
        hideAllHints(state) {
            Object.values(state.partState).forEach((partState) => (partState.hintsShown = []));
        },
        hideHintsForPart(state, action) {
            Maybe.maybe(state.partState[action.payload]).lift((partState) => (partState.hintsShown = []));
        },
    },
});
const slice = activityDeliverySlice;
export const requestHint = (partId, onRequestHint) => (dispatch, getState) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    const attemptGuid = (_a = getState().attemptState.parts.find((part) => String(part.partId) === partId)) === null || _a === void 0 ? void 0 : _a.attemptGuid;
    if (!attemptGuid)
        return;
    const response = yield onRequestHint(getState().attemptState.attemptGuid, attemptGuid);
    Maybe.maybe(response.hint).lift((hint) => dispatch(slice.actions.showHintForPart({ partId, hint })));
    dispatch(slice.actions.setHasMoreHintsForPart({ partId, hasMoreHints: response.hasMoreHints }));
});
export const selectAttemptState = (state) => state.attemptState;
export const isEvaluated = (state) => selectAttemptState(state).score !== null;
export const resetAction = (onResetActivity, partInputs) => (dispatch, getState) => __awaiter(void 0, void 0, void 0, function* () {
    const response = yield onResetActivity(getState().attemptState.attemptGuid);
    dispatch(slice.actions.setPartInputs(partInputs));
    dispatch(slice.actions.hideAllHints());
    dispatch(slice.actions.setAttemptState(response.attemptState));
    getState().attemptState.parts.forEach((partState) => dispatch(slice.actions.setHasMoreHintsForPart({
        partId: String(partState.partId),
        hasMoreHints: partState.hasMoreHints,
    })));
});
export const submit = (onSubmitActivity) => (dispatch, getState) => __awaiter(void 0, void 0, void 0, function* () {
    const response = yield onSubmitActivity(getState().attemptState.attemptGuid, getState().attemptState.parts.map((partState) => {
        var _a;
        return ({
            attemptGuid: partState.attemptGuid,
            response: {
                input: studentInputToString(Maybe.maybe((_a = getState().partState[String(partState.partId)]) === null || _a === void 0 ? void 0 : _a.studentInput).valueOr([''])),
            },
        });
    }));
    dispatch(slice.actions.activitySubmissionReceived(response));
});
export const initializeState = (state, initialPartInputs) => (dispatch, _getState) => __awaiter(void 0, void 0, void 0, function* () {
    dispatch(slice.actions.initializePartState(state));
    state.parts.forEach((partState) => {
        dispatch(slice.actions.setHintsShownForPart({
            partId: String(partState.partId),
            hintsShown: partState.hints,
        }));
        dispatch(slice.actions.setHasMoreHintsForPart({
            partId: String(partState.partId),
            hasMoreHints: partState.hasMoreHints,
        }));
    });
    dispatch(slice.actions.setAttemptState(state));
    dispatch(slice.actions.setPartInputs(initialPartInputs));
});
export const setSelection = (partId, selection, onSaveActivity, type) => (dispatch, getState) => __awaiter(void 0, void 0, void 0, function* () {
    var _b, _c;
    const attemptGuid = (_b = getState().attemptState.parts.find((part) => String(part.partId) === partId)) === null || _b === void 0 ? void 0 : _b.attemptGuid;
    if (!attemptGuid)
        return;
    // Update local state by adding or removing the id
    if (type === 'single') {
        dispatch(slice.actions.setStudentInputForPart({ partId, studentInput: [selection] }));
    }
    else if (type === 'multiple') {
        dispatch(slice.actions.updateChoiceSelectionMultiple({ partId, selection }));
    }
    // Post the student response to save it
    // Here we will make a list of the selected ids like { input: [id1, id2, id3].join(' ')}
    // Then in the rule evaluator, we will say
    // `input like id1 && input like id2 && input like id3`
    const newSelection = (_c = getState().partState[partId]) === null || _c === void 0 ? void 0 : _c.studentInput;
    if (!newSelection)
        return;
    return onSaveActivity(getState().attemptState.attemptGuid, [
        {
            attemptGuid,
            response: { input: studentInputToString(newSelection) },
        },
    ]);
});
//# sourceMappingURL=DeliveryState.js.map