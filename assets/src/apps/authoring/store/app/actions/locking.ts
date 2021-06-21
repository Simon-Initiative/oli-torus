import { createAsyncThunk } from '@reduxjs/toolkit';
import { acquireLock, releaseLock } from 'data/persistence/lock';
import { RootState } from '../../rootReducer';
import { AppSlice, selectProjectSlug, selectRevisionSlug } from '../slice';

export const acquireEditingLock = createAsyncThunk(
  `${AppSlice}/acquireEditingLock`,
  async (_, { getState }) => {
    const projectSlug = selectProjectSlug(getState() as RootState);
    const resourceSlug = selectRevisionSlug(getState() as RootState);
    const lockResult = await acquireLock(projectSlug, resourceSlug);
    if (lockResult.type !== 'acquired') {
      throw new Error('acquiring lock failed');
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
