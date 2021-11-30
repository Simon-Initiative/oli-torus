import { createAsyncThunk } from '@reduxjs/toolkit';
import { AppSlice, selectReadOnly } from '../slice';

export const attemptDisableReadOnly = createAsyncThunk(
  `${AppSlice}/attemptDisableReadOnly`,
  async (payload, { dispatch, getState }) => {
    const rootState = getState() as any;
    const isReadOnly = selectReadOnly(rootState);

    if (!isReadOnly) {
      return;
    }
  },
);
