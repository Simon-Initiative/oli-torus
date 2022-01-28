import { createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { HistorySlice, selectRedoAction } from '../slice';
import reverse from 'lodash/reverse';

export const redo = createAsyncThunk(
  `${HistorySlice}/redo`,
  async (payload: null, { getState, dispatch }) => {
    const rootState = getState() as any;
    const present = selectRedoAction(rootState) || { redo: [] };
    reverse(present.redo).forEach((a: PayloadAction) => {
      dispatch(a);
    });
  },
);
