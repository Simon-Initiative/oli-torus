import { createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { selectRedoAction, selectState } from '../slice';
import { HistorySlice } from '../name';
import reverse from 'lodash/reverse';

export const redo = createAsyncThunk(
  `${HistorySlice}/redo`,
  async (payload: null, { getState, dispatch }) => {
    const rootState = getState() as any;
    const present = selectRedoAction(rootState) || { redo: [] };
    const state = selectState(rootState);

    reverse(present.redo).forEach((a: PayloadAction) => {
      dispatch(a);
    });
  },
);
