import { createAsyncThunk } from '@reduxjs/toolkit';
import { AppSlice, selectReadOnly, setReadonly } from '../slice';

export const attemptDisableReadOnly = createAsyncThunk(
  `${AppSlice}/attemptDisableReadOnly`,
  async (payload, { dispatch, getState }) => {
    const rootState = getState() as any;
    const isReadOnly = selectReadOnly(rootState);

    if (!isReadOnly) {
      throw new Error('Cannot disable read-only mode');
    }

    dispatch(setReadonly({ readonly: false }));

    return;
  },
);
