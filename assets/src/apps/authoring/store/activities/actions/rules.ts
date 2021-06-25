import { createAsyncThunk } from '@reduxjs/toolkit';
import guid from 'utils/guid';
import {
  ActivitiesSlice,
  selectActivityById,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { createFeedback } from './createFeedback';

export const createCorrectRule = createAsyncThunk(
  `${ActivitiesSlice}/createCorrectRule`,
  async (payload: any, { dispatch, getState }) => {
    const { ruleId = `r:${guid()}`, isDefault = false, activityId } = payload;

    const rule = {
      id: `${ruleId}.correct`,
      name: 'correct',
      disabled: false,
      additionalScore: 0.0,
      forceProgress: false,
      default: isDefault,
      correct: true,
      conditions: { all: [] },
      event: {
        type: `${ruleId}.correct`,
        params: {
          actions: [
            {
              type: 'navigation',
              params: { target: 'next' },
            },
          ],
        },
      },
    };

    // when creating a rule it should always be for use in an activity
    const activity = selectActivityById(getState() as any, activityId);
    const modifiedActivity = JSON.parse(JSON.stringify(activity));
    // need to ensure this path exists?
    modifiedActivity.model.authoring.rules.push(rule);
    await dispatch(upsertActivity({ activity: modifiedActivity }));

    return rule;
  },
);

export const createIncorrectRule = createAsyncThunk(
  `${ActivitiesSlice}/createIncorrectRule`,
  async (payload: any, { dispatch, getState }) => {
    const { ruleId = `r:${guid()}`, isDefault = false, activityId } = payload;

    const { payload: feedbackAction } = await dispatch(createFeedback({}));

    const name = isDefault ? 'defaultWrong' : 'incorrect';

    const rule = {
      id: `${ruleId}.${name}`,
      name,
      disabled: false,
      additionalScore: 0.0,
      forceProgress: false,
      default: true,
      correct: false,
      conditions: { all: [] },
      event: {
        type: `${ruleId}.${name}`,
        params: {
          actions: [feedbackAction],
        },
      },
    };

    // when creating a rule it should always be for use in an activity
    const activity = selectActivityById(getState() as any, activityId);
    const modifiedActivity = JSON.parse(JSON.stringify(activity));
    // need to ensure this path exists?
    modifiedActivity.model.authoring.rules.push(rule);
    await dispatch(upsertActivity({ activity: modifiedActivity }));

    return rule;
  },
);
