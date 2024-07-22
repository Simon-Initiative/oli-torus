import { PayloadAction, Slice, createSelector, createSlice } from '@reduxjs/toolkit';
import { AuthoringRootState } from '../rootReducer';
import PartsSlice from './name';

export interface PartState {
  currentSelection: string;
  currentPartPropertyFocus?: boolean;
}

const initialState: PartState = {
  currentSelection: '',
  currentPartPropertyFocus: false,
};

const slice: Slice<PartState> = createSlice({
  name: PartsSlice,
  initialState,
  reducers: {
    setCurrentSelection(state, action: PayloadAction<{ selection: string }>) {
      state.currentSelection = action.payload.selection;
    },
    setCurrentPartPropertyFocus(state, action: PayloadAction<{ focus: boolean }>) {
      state.currentPartPropertyFocus = action.payload.focus;
    },
  },
});

export const { setCurrentSelection, setCurrentPartPropertyFocus } = slice.actions;

export const selectState = (state: AuthoringRootState): PartState => state[PartsSlice] as PartState;
export const selectCurrentSelection = createSelector(selectState, (s) => s.currentSelection);
export const selectCurrentPartPropertyFocus = createSelector(
  selectState,
  (s) => s.currentPartPropertyFocus,
);

export default slice.reducer;
