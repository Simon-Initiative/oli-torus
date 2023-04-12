import { AuthoringRootState } from '../rootReducer';
import PartsSlice from './name';
import { PayloadAction, Slice, createSelector, createSlice } from '@reduxjs/toolkit';

export interface PartState {
  currentSelection: string;
}

const initialState: PartState = {
  currentSelection: '',
};

const slice: Slice<PartState> = createSlice({
  name: PartsSlice,
  initialState,
  reducers: {
    setCurrentSelection(state, action: PayloadAction<{ selection: string }>) {
      state.currentSelection = action.payload.selection;
    },
  },
});

export const { setCurrentSelection } = slice.actions;

export const selectState = (state: AuthoringRootState): PartState => state[PartsSlice] as PartState;
export const selectCurrentSelection = createSelector(selectState, (s) => s.currentSelection);

export default slice.reducer;
