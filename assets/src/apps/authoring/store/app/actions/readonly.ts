import { createAsyncThunk } from '@reduxjs/toolkit';
import { AppSlice, selectReadOnly, setReadonly } from '../slice';
import { acquireEditingLock } from './locking';

export const attemptDisableReadOnly = createAsyncThunk(
  `${AppSlice}/attemptDisableReadOnly`,
  async (payload, { dispatch, getState, rejectWithValue }) => {
    const rootState = getState() as any;
    const isReadOnly = selectReadOnly(rootState);

    if (!isReadOnly) {
      return rejectWithValue('Cannot disable read-only mode, already disabled.');
    }

    try {
      const lockResult = await dispatch(acquireEditingLock()); // .unwrap();
      console.log('attemptDisableReadOnly: lockResult', lockResult);
      if (lockResult.meta.requestStatus !== 'fulfilled') {
        return rejectWithValue('Cannot acquire lock');
      }
    } catch (error) {
      return rejectWithValue('Cannot disable read-only mode, locked by another user');
    }

    console.log('attemptDisableReadOnly: success');

    dispatch(setReadonly({ readonly: false }));

    return;
  },
);
