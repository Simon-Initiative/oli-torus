import { createAsyncThunk } from '@reduxjs/toolkit';
import { ActivityState } from 'components/activities/types';
import { createNewActivityAttempt } from 'data/persistence/state/intrinsic';
import guid from 'utils/guid';
import { RootState } from '../../../../store/rootReducer';
import { selectPreviewMode } from '../../page/slice';
import { AttemptSlice, selectById, upsertActivityAttemptState } from '../slice';

export const createActivityAttempt = createAsyncThunk(
  `${AttemptSlice}/createActivityAttempt`,
  async (payload: any, { dispatch, getState }) => {
    const { sectionSlug, attemptGuid } = payload;
    const rootState = getState() as RootState;
    const isPreviewMode = selectPreviewMode(rootState);

    let attempt = selectById(rootState, attemptGuid);
    if (!attempt) {
      throw new Error(`Unable to find attempt with guid: ${attemptGuid}`);
    }
    const resourceId = attempt.activityId;
    if (isPreviewMode) {
      // make mutable
      attempt = JSON.parse(JSON.stringify(attempt)) as ActivityState;
      attempt.attemptNumber += 1;
      attempt.attemptGuid = `npreview_${guid()}`;
    } else {
      const seedResponses = true; // parameterize at function level?
      const new_attempt_result = await createNewActivityAttempt(sectionSlug, attemptGuid, seedResponses);
      console.log({ new_attempt_result });
      attempt = new_attempt_result.attemptState as ActivityState;
      // this should be for the same resource id, which doesn't come back from the server
      // because it's already based on the previous attemptGuid
      attempt.activityId = resourceId;
    }

    await dispatch(upsertActivityAttemptState({ attempt }));
  },
);
