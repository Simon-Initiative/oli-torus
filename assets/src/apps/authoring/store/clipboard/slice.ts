import { createSelector, createSlice, PayloadAction, Slice } from '@reduxjs/toolkit';
import { RootState } from '../rootReducer';
import ClipboardSlice from './name';

export type CopyableItemTypes = 'rule' | 'initState';

export interface ClipboardState {
  item: any;
  type: CopyableItemTypes | null;
}

const initialState: ClipboardState = {
  item: null,
  type: null,
};

const slice: Slice<ClipboardState> = createSlice({
  name: ClipboardSlice,
  initialState,
  reducers: {
    copyItem(state, action: PayloadAction<{ item: any; type: CopyableItemTypes }>) {
      const { payload } = action;
      const { item, type } = payload;
      state.item = item;
      state.type = type;
    },
    pasteItem(state) {
      state.item = null;
      state.type = null;
    },
  },
});

export const { copyItem, pasteItem } = slice.actions;

export const selectState = (state: RootState): ClipboardState =>
  state[ClipboardSlice] as ClipboardState;

export const selectCopiedItem = createSelector(selectState, (state: ClipboardState) => state.item);
export const selectCopiedType = createSelector(selectState, (state: ClipboardState) => state.type);

export default slice.reducer;
