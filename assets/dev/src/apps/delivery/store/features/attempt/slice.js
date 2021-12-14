import { createEntityAdapter, createSelector, createSlice, } from '@reduxjs/toolkit';
const adapter = createEntityAdapter({
    selectId: (item) => item.attemptGuid,
});
const slice = createSlice({
    name: 'attempt',
    initialState: adapter.getInitialState({
        resourceAttemptGuid: '',
        extrinsic: {
            'session.attemptNumber': 1,
            'session.timeOnQuestion': 0,
            'session.timeQuestionStart': 0,
        },
    }),
    reducers: {
        setResourceAttemptGuid(state, action) {
            state.resourceAttemptGuid = action.payload.guid;
        },
        setExtrinsicState(state, action) {
            state.extrinsic = action.payload.state;
        },
        updateExtrinsicState(state, action) {
            state.extrinsic = Object.assign(Object.assign({}, state.extrinsic), action.payload.state);
        },
        loadActivityAttemptState(state, action) {
            adapter.setAll(state, action.payload.attempts);
        },
        upsertActivityAttemptState(state, action) {
            // we only want to keep the latest attempt record for any activityId
            const existing = adapter
                .getSelectors()
                .selectAll(state)
                .filter((attempt) => attempt.activityId === action.payload.attempt.activityId &&
                attempt.attemptGuid !== action.payload.attempt.attemptGuid);
            if (existing.length) {
                adapter.removeMany(state, existing.map((e) => e.attemptGuid));
            }
            adapter.upsertOne(state, action.payload.attempt);
        },
    },
});
export const AttemptSlice = slice.name;
export const { setResourceAttemptGuid, setExtrinsicState, updateExtrinsicState, loadActivityAttemptState, upsertActivityAttemptState, } = slice.actions;
export const selectState = (state) => state[AttemptSlice];
export const { selectAll, selectById, selectTotal } = adapter.getSelectors(selectState);
export const selectActivityAttemptState = (state, activityId) => {
    const attempts = selectAll(state);
    const attempt = attempts.find((a) => a.activityId === activityId);
    return attempt;
};
export const selectExtrinsicState = createSelector(selectState, (state) => state.extrinsic);
export default slice.reducer;
//# sourceMappingURL=slice.js.map