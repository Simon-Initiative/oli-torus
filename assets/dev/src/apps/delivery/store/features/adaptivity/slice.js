import { createSelector, createSlice } from '@reduxjs/toolkit';
const initialState = {
    isGoodFeedback: false,
    currentFeedbacks: [],
    nextActivityId: '',
    lastCheckTriggered: null,
    lastCheckResults: {
        timestamp: -1,
        results: [],
        attempt: null,
        correct: false,
        score: 0,
        outOf: 0,
    },
    restartLesson: false,
    lessonEnded: false,
    lastMutateTriggered: null,
    lastMutateChanges: null,
    initPhaseComplete: null,
    historyModeNavigation: false,
    initStateFacts: [],
};
const slice = createSlice({
    name: 'adaptivity',
    initialState,
    reducers: {
        setIsGoodFeedback: (state, action) => {
            state.isGoodFeedback = action.payload.isGood;
        },
        setNextActivityId: (state, action) => {
            state.nextActivityId = action.payload.activityId;
        },
        setCurrentFeedbacks: (state, action) => {
            state.currentFeedbacks = action.payload.feedbacks;
        },
        setLastCheckTriggered: (state, action) => {
            state.lastCheckTriggered = action.payload.timestamp;
        },
        setLastCheckResults: (state, action) => {
            const { results, attempt, timestamp, correct, score, outOf } = action.payload;
            state.lastCheckResults = { results, attempt, timestamp, correct, score, outOf };
        },
        setRestartLesson(state, action) {
            state.restartLesson = action.payload.restartLesson;
        },
        setLessonEnd(state, action) {
            state.lessonEnded = action.payload.lessonEnded;
        },
        setMutationTriggered(state, action) {
            state.lastMutateTriggered = Date.now();
            state.lastMutateChanges = action.payload.changes;
        },
        setHistoryNavigationTriggered(state, action) {
            state.historyModeNavigation = action.payload.historyModeNavigation;
        },
        setInitPhaseComplete(state) {
            state.initPhaseComplete = Date.now();
        },
        setInitStateFacts(state, action) {
            state.initStateFacts = action.payload.facts;
        },
    },
});
export const AdaptivitySlice = slice.name;
export const { setIsGoodFeedback, setNextActivityId, setCurrentFeedbacks, setLastCheckTriggered, setLastCheckResults, setRestartLesson, setLessonEnd, setMutationTriggered, setInitPhaseComplete, setHistoryNavigationTriggered, setInitStateFacts, } = slice.actions;
// selectors
export const selectState = (state) => state[AdaptivitySlice];
export const selectIsGoodFeedback = createSelector(selectState, (state) => state.isGoodFeedback);
export const selectCurrentFeedbacks = createSelector(selectState, (state) => state.currentFeedbacks);
export const selectNextActivityId = createSelector(selectState, (state) => state.nextActivityId);
export const selectRestartLesson = createSelector(selectState, (state) => state.restartLesson);
export const selectLessonEnd = createSelector(selectState, (state) => state.lessonEnded);
export const selectLastCheckTriggered = createSelector(selectState, (state) => state.lastCheckTriggered);
export const selectLastCheckResults = createSelector(selectState, (state) => state.lastCheckResults);
export const selectHistoryNavigationActivity = createSelector(selectState, (state) => state.historyModeNavigation);
export const selectInitStateFacts = createSelector(selectState, (state) => state.initStateFacts);
export const selectLastMutateTriggered = createSelector(selectState, (state) => state.lastMutateTriggered);
export const selectLastMutateChanges = createSelector(selectState, (state) => state.lastMutateChanges);
export const selectInitPhaseComplete = createSelector(selectState, (state) => state.initPhaseComplete);
export default slice.reducer;
//# sourceMappingURL=slice.js.map