import { createSelector, createSlice, PayloadAction, Slice } from '@reduxjs/toolkit';
import { RootState } from '../rootReducer';
import { undo } from './actions/undo';
import { redo } from './actions/redo';
import guid from 'utils/guid';
import { HistorySlice } from './name';

export interface UndoAction {
  id: string;
  undo: PayloadAction[];
  redo: PayloadAction[];
}

export interface AuthoringHistoryState {
  past: UndoAction[];
  present?: UndoAction;
  future: UndoAction[];
}

const initialState: AuthoringHistoryState = {
  past: [],
  present: undefined,
  future: [],
};

const slice: Slice<AuthoringHistoryState> = createSlice({
  name: HistorySlice,
  initialState,
  reducers: {
    createUndoAction(state, action: PayloadAction<UndoAction>) {
      if (state.present) {
        state.past.unshift(state.present);
      }
      state.present = { ...action.payload, id: guid() };
      state.future = [];

      return state;
    },
  },
  extraReducers: (builder) => {
    builder.addCase(undo.fulfilled, (state) => {
      const { future, present, past } = state;
      if (present) {
        future.unshift(present);
      }
      state.present = past.shift();
      state.past = [...past];
      state.future = [...future];
    });
    builder.addCase(redo.fulfilled, (state) => {
      const { future, present, past } = state;
      if (present) {
        past.unshift(present);
      }
      state.present = future.shift();
      state.past = [...past];
      state.future = [...future];
    });
  },
});

export const { createUndoAction } = slice.actions;

export const selectState = (state: RootState): AuthoringHistoryState =>
  state[HistorySlice] as AuthoringHistoryState;

export const selectHasUndo = createSelector(
  selectState,
  (state: AuthoringHistoryState) => !!state.present,
);
export const selectHasRedo = createSelector(
  selectState,
  (state: AuthoringHistoryState) => state.future.length > 0,
);

export const selectPresentAction = createSelector(
  selectState,
  (state: AuthoringHistoryState) => state.present,
);

export const selectRedoAction = createSelector(
  selectState,
  (state: AuthoringHistoryState) => state.future[0],
);

export default slice.reducer;
