import { createAsyncThunk } from '@reduxjs/toolkit';
import { acquireLock, releaseLock } from 'data/persistence/lock';
import { RootState } from '../../rootReducer';
import { AppSlice, selectProjectSlug, selectRevisionSlug } from '../slice';

export const acquireEditingLock = createAsyncThunk(
  `${AppSlice}/acquireEditingLock`,
  async (_, { getState, rejectWithValue }) => {
    const projectSlug = selectProjectSlug(getState() as RootState);
    const resourceSlug = selectRevisionSlug(getState() as RootState);

    try {
      const lockResult = await acquireLock(projectSlug, resourceSlug);
      if (lockResult.type !== 'acquired') {
        return rejectWithValue({
          error: 'ALREADY_LOCKED',
          msg: 'Error acquiring a lock, most likely due to another user already owning the lock.',
        });
      }
    } catch (e) {
      return rejectWithValue({
        error: 'SERVER_ERROR',
        server: e,
        msg: 'Server error attempting to acquire lock, this is most likely a session timeout',
      });
    }
  },
);

export const releaseEditingLock = createAsyncThunk(
  `${AppSlice}/releaseEditingLock`,
  async (_, { getState }) => {
    const projectSlug = selectProjectSlug(getState() as RootState);
    const resourceSlug = selectRevisionSlug(getState() as RootState);
    const lockResult = await releaseLock(projectSlug, resourceSlug);
    if (lockResult.type !== 'released') {
      throw new Error('releasing lock failed');
    }
  },
);
