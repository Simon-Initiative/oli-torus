import { createAsyncThunk } from '@reduxjs/toolkit';
import { createNewActivityAttempt } from 'data/persistence/state/intrinsic';
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
    if (isPreviewMode) {
      // create a new one in redux (maybe not necessary, just increase attempt number)
    } else {
      const new_attempt_result = await createNewActivityAttempt(sectionSlug, attemptGuid);
      console.log({ new_attempt_result });
      attempt = new_attempt_result.attemptState;
    }

    await dispatch(upsertActivityAttemptState({ attempt }));
  },
);
