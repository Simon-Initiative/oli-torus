import { createAsyncThunk } from '@reduxjs/toolkit';
import { RootState } from 'apps/delivery/store/rootReducer';
import { writePartAttemptState } from 'data/persistence/state/intrinsic';
import { selectPreviewMode, selectSectionSlug } from '../../page/slice';
import { AttemptSlice, selectById, upsertActivityAttemptState } from '../slice';

export const savePartState = createAsyncThunk(
  `${AttemptSlice}/savePartState`,
  async (payload: any, { dispatch, getState }) => {
    const { attemptGuid, partAttemptGuid, response } = payload;
    const rootState = getState() as RootState;
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);

    // update redux state to match optimistically
    const attemptRecord = selectById(rootState, attemptGuid);
    if (attemptRecord) {
      const partAttemptRecord = attemptRecord.parts.find((p) => p.attemptGuid === partAttemptGuid);
      if (partAttemptRecord) {
        const updated = {
          ...attemptRecord,
          parts: attemptRecord.parts.map((p) => {
            const result = { ...p };
            if (p.attemptGuid === partAttemptRecord.attemptGuid) {
              result.response = response;
            }
            return result;
          }),
        };
        await dispatch(upsertActivityAttemptState({ attempt: updated }));
      }
    }

    // in preview mode the write function will write to the scripting env
    // in order for that to process properly we need to attach the sequenceId

    return writePartAttemptState(
      sectionSlug,
      attemptGuid,
      partAttemptGuid,
      response,
      false,
      isPreviewMode,
    );
  },
);
