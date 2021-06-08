import { createAsyncThunk } from '@reduxjs/toolkit';
import { writeActivityAttemptState } from 'data/persistence/state/intrinsic';
import {
  defaultGlobalEnv,
  evalScript,
  getAssignScript,
} from '../../../../../../adaptivity/scripting';
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

    // update script env with latest values
    const assignScript = getAssignScript(partResponses);
    const { result: scriptResult } = evalScript(assignScript, defaultGlobalEnv);

    // in preview mode we don't talk to the server, so we're done
    if (isPreviewMode) {
      // TODO: normalize result response between client and server (currently nothing cares)
      return { result: scriptResult };
    }

    const finalize = true;

    return writeActivityAttemptState(sectionSlug, attemptGuid, partResponses, finalize);
  },
);
