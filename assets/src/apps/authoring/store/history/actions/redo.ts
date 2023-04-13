import { PayloadAction, createAsyncThunk } from '@reduxjs/toolkit';
import reverse from 'lodash/reverse';
import { HistorySlice } from '../name';
import { selectRedoAction, selectState } from '../slice';

export const redo = createAsyncThunk(
  `${HistorySlice}/redo`,
  async (payload: null, { getState, dispatch }) => {
    const rootState = getState() as any;
    const present = selectRedoAction(rootState) || { redo: [] };
    const _state = selectState(rootState);

    reverse(present.redo).forEach((a: PayloadAction) => {
      dispatch(a);
    });
  },
);
