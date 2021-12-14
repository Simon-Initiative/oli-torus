import { createEntityAdapter, createSelector, createSlice, } from '@reduxjs/toolkit';
const adapter = createEntityAdapter();
const slice = createSlice({
    name: 'activities',
    initialState: adapter.getInitialState({
        currentActivityId: '',
    }),
    reducers: {
        setActivities(state, action) {
            adapter.setAll(state, action.payload.activities);
        },
        upsertActivity(state, action) {
            adapter.upsertOne(state, action.payload.activity);
        },
        upsertActivities(state, action) {
            adapter.upsertMany(state, action.payload.activities);
        },
        deleteActivity(state, action) {
            adapter.removeOne(state, action.payload.activityId);
        },
        deleteActivities(state, action) {
            adapter.removeMany(state, action.payload.ids);
        },
        setCurrentActivityId(state, action) {
            state.currentActivityId = action.payload.activityId;
        },
    },
});
export const ActivitiesSlice = slice.name;
export const { setActivities, upsertActivity, upsertActivities, deleteActivity, deleteActivities, setCurrentActivityId, } = slice.actions;
// SELECTORS
export const selectState = (state) => state[ActivitiesSlice];
export const selectCurrentActivityId = createSelector(selectState, (state) => state.currentActivityId);
const { selectAll, selectById, selectTotal, selectEntities } = adapter.getSelectors(selectState);
export const selectAllActivities = selectAll;
export const selectActivityById = selectById;
export const selectTotalActivities = selectTotal;
export const selectCurrentActivity = createSelector([selectEntities, selectCurrentActivityId], (activities, currentActivityId) => activities[currentActivityId]);
export const selectCurrentActivityContent = createSelector(selectCurrentActivity, (activity) => activity === null || activity === void 0 ? void 0 : activity.content);
export default slice.reducer;
//# sourceMappingURL=slice.js.map