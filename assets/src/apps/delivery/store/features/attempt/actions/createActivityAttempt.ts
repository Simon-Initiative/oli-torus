import { createAsyncThunk } from '@reduxjs/toolkit';
import { ActivityState } from 'components/activities/types';
import { createNewActivityAttempt } from 'data/persistence/state/intrinsic';
import guid from 'utils/guid';
import { DeliveryRootState } from '../../../../store/rootReducer';
import { selectPreviewMode } from '../../page/slice';
import { selectById, upsertActivityAttemptState } from '../slice';
import AttemptSlice from '../name';

export const createActivityAttempt = createAsyncThunk(
  `${AttemptSlice}/createActivityAttempt`,
  async (payload: any, { dispatch, getState }) => {
    const { sectionSlug, attemptGuid } = payload;
    const rootState = getState() as DeliveryRootState;
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
      attempt.score = 0;
      attempt.outOf = 0;
      attempt.dateEvaluated = null;
      attempt.dateSubmitted = null;
      // keep the part responses
    } else {
      const seedResponses = true; // parameterize at function level?
      const new_attempt_result = await createNewActivityAttempt(
        sectionSlug,
        attemptGuid,
        seedResponses,
      );
      /* console.log({ new_attempt_result }); */
      attempt = new_attempt_result.attemptState as ActivityState;
      // this should be for the same resource id, which doesn't come back from the server
      // because it's already based on the previous attemptGuid
      attempt.activityId = resourceId;
    }

    await dispatch(upsertActivityAttemptState({ attempt }));

    return attempt;
  },
);
