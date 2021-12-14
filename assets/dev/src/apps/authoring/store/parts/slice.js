import { createSelector, createSlice } from '@reduxjs/toolkit';
const initialState = {
    currentSelection: '',
};
const slice = createSlice({
    name: 'parts',
    initialState,
    reducers: {
        setCurrentSelection(state, action) {
            state.currentSelection = action.payload.selection;
        },
    },
});
export const PartsSlice = slice.name;
export const { setCurrentSelection } = slice.actions;
export const selectState = (state) => state[PartsSlice];
export const selectCurrentSelection = createSelector(selectState, (s) => s.currentSelection);
export default slice.reducer;
//# sourceMappingURL=slice.js.map