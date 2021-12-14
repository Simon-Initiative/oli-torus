import { makeFeedback, makeHint, } from 'components/activities/types';
const partState = {
    attemptGuid: 'guid',
    attemptNumber: 1,
    dateEvaluated: null,
    score: null,
    outOf: 1,
    response: null,
    feedback: 'feedback',
    hints: [],
    partId: 1,
    hasMoreAttempts: true,
    hasMoreHints: true,
};
export const attemptState = {
    attemptGuid: 'guid',
    attemptNumber: 1,
    dateEvaluated: null,
    score: null,
    outOf: 1,
    parts: [partState],
    hasMoreAttempts: true,
    hasMoreHints: true,
};
const feedbackAction = {
    type: 'FeedbackAction',
    attempt_guid: '1',
    out_of: 1,
    score: 1,
    feedback: makeFeedback('correct feedback'),
};
const evaluationResponse = {
    type: 'success',
    actions: [feedbackAction],
};
const requestHintResponse = {
    type: 'success',
    hint: makeHint('hint'),
    hasMoreHints: false,
};
const onSubmitActivity = jest.fn().mockImplementation(() => Promise.resolve(evaluationResponse));
const onSaveActivity = jest.fn();
const onResetActivity = jest.fn();
const onRequestHint = jest.fn().mockImplementation(() => Promise.resolve(requestHintResponse));
const onSavePart = jest.fn();
const onSubmitPart = jest.fn();
const onResetPart = jest.fn();
const onSubmitEvaluations = jest.fn();
export const defaultDeliveryElementProps = {
    onSaveActivity,
    onSubmitActivity,
    onResetActivity,
    onRequestHint,
    onSavePart,
    onSubmitPart,
    onResetPart,
    onSubmitEvaluations,
    state: attemptState,
    mode: 'delivery',
    userId: 1,
};
export const defaultAuthoringElementProps = (initialModel) => {
    const model = initialModel;
    return {
        projectSlug: '',
        editMode: true,
        model,
        onPostUndoable: jest.fn(),
        onRequestMedia: jest.fn(),
        onEdit: (newModel) => Object.assign(model, newModel),
    };
};
//# sourceMappingURL=activity_mocks.js.map