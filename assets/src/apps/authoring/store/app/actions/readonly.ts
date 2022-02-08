import { createAsyncThunk } from '@reduxjs/toolkit';
import { selectReadOnly, setReadonly } from '../slice';
import AppSlice from '../name';
import { acquireEditingLock } from './locking';

export const attemptDisableReadOnly = createAsyncThunk(
  `${AppSlice}/attemptDisableReadOnly`,
  async (payload, { dispatch, getState, rejectWithValue }) => {
    const rootState = getState() as any;
    const isReadOnly = selectReadOnly(rootState);

    if (!isReadOnly) {
      return rejectWithValue({
        error: 'ALREADY_DISABLED',
        msg: 'Cannot disable read-only mode, already disabled.',
      });
    }

    try {
      const lockResult = await dispatch(acquireEditingLock()); // .unwrap();
      // console.log('attemptDisableReadOnly: lockResult', lockResult);
      if (lockResult.meta.requestStatus !== 'fulfilled') {
        let error = 'LOCK_FAILED';
        const lockErrorCode = (lockResult as any)?.payload?.error;
        let msg = 'Failed to acquire editing lock.';
        if (lockErrorCode === 'ALREADY_LOCKED') {
          msg = (lockResult as any)?.payload?.msg;
          error = lockErrorCode;
        }
        if (lockErrorCode === 'SERVER_ERROR') {
          msg = (lockResult as any)?.payload?.msg;
          error = 'SESSION_EXPIRED';
        }
        return rejectWithValue({ error, msg });
      }
    } catch (error) {
      return rejectWithValue({
        error: 'EXCEPTION',
        exception: error,
        msg: 'Cannot disable read-only mode, exception',
      });
    }

    // console.log('attemptDisableReadOnly: success');

    dispatch(setReadonly({ readonly: false }));

    return;
  },
);
