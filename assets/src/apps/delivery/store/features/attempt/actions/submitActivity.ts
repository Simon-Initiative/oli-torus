import { createAsyncThunk } from '@reduxjs/toolkit';
import { writeActivityAttemptState } from 'data/persistence/state/intrinsic';
import { RootState } from '../../../rootReducer';
import { selectPreviewMode, selectSectionSlug } from '../../page/slice';
import { AttemptSlice, selectById, upsertActivityAttemptState } from '../slice';

export const submitActivityState = createAsyncThunk(
  `${AttemptSlice}/submitActivityState`,
  async (payload: any, { dispatch, getState }) => {
    const { attemptGuid, partResponses } = payload;
    const rootState = getState() as RootState;
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);

    // update redux state to match optimistically
    const attemptRecord = selectById(rootState, attemptGuid);
    if (attemptRecord) {
      const updated = {
        ...attemptRecord,
        parts: partResponses,
      };
      await dispatch(upsertActivityAttemptState({ attempt: updated }));
    }

    // in preview mode the write function will write to the scripting env
    // in order for that to process properly we need to attach the sequenceId

    return writeActivityAttemptState(
      sectionSlug,
      attemptGuid,
      partResponses,
      true,
      isPreviewMode,
    );
  },
);
