import { createAsyncThunk } from '@reduxjs/toolkit';
import { writePartAttemptState } from 'data/persistence/state/intrinsic';
import { defaultGlobalEnv, evalScript, getAssignScript } from '../../../../../../adaptivity/scripting';
import { RootState } from '../../../rootReducer';
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

    // update scripting env with latest values
    const assignScript = getAssignScript(response);
    const { result: scriptResult } = evalScript(assignScript, defaultGlobalEnv);

    // in preview mode we don't write to server, so we're done
    if (isPreviewMode) {
      // TODO: normalize response between client and server (nothing currently cares about it)
      return { result: scriptResult };
    }

    const finalize = false;

    return writePartAttemptState(
      sectionSlug,
      attemptGuid,
      partAttemptGuid,
      response,
      finalize,
    );
  },
);
