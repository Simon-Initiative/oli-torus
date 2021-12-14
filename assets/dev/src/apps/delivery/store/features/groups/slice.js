import { createEntityAdapter, createSelector, createSlice, } from '@reduxjs/toolkit';
export var LayoutType;
(function (LayoutType) {
    LayoutType["DECK"] = "deck";
    LayoutType["UNKNOWN"] = "unknown";
})(LayoutType || (LayoutType = {}));
const adapter = createEntityAdapter();
const slice = createSlice({
    name: 'groups',
    initialState: adapter.getInitialState({
        currentGroupId: -1,
    }),
    reducers: {
        setCurrentGroupId(state, action) {
            state.currentGroupId = action.payload.groupId;
        },
        setGroups(state, action) {
            // groups aren't currently having resourceIds so we need to set id via index
            const groups = action.payload.groups.map((group, index) => {
                const id = group.id !== undefined ? group.id : index + 1;
                // careful, doesn't handle nested groups
                const children = group.children.map((child) => {
                    if (child.type === 'activity-reference') {
                        const resourceId = child.activity_id || child.activityId || child.resourceId;
                        return Object.assign(Object.assign({}, child), { resourceId });
                    }
                    return child;
                });
                return Object.assign(Object.assign({}, group), { id, children });
            });
            adapter.setAll(state, groups);
            // for now just select first one (dont even have a multi group concept yet)
            state.currentGroupId = groups[0].id;
        },
        upsertGroup(state, action) {
            adapter.upsertOne(state, action.payload.group);
        },
    },
});
export const GroupsSlice = slice.name;
export const { setCurrentGroupId, setGroups, upsertGroup } = slice.actions;
export const selectState = (state) => state[GroupsSlice];
export const { selectAll, selectById, selectTotal } = adapter.getSelectors(selectState);
export const selectCurrentGroup = createSelector(selectState, (state) => state.entities[state.currentGroupId]);
export default slice.reducer;
//# sourceMappingURL=slice.js.map