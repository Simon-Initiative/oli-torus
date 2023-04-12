import HistorySlice from '../name';
import { selectPresentAction } from '../slice';
import { PayloadAction, createAsyncThunk } from '@reduxjs/toolkit';
import reverse from 'lodash/reverse';

export const undo = createAsyncThunk(
  `${HistorySlice}/undo`,
  async (payload: null, { getState, dispatch }) => {
    const rootState = getState() as any;
    const present = selectPresentAction(rootState) || { undo: [] };
    reverse(present.undo).forEach((a: PayloadAction) => {
      dispatch(a);
    });
  },
);
