import { createAsyncThunk } from '@reduxjs/toolkit';
import guid from 'utils/guid';
import { ActivitiesSlice } from '../../../../delivery/store/features/activities/slice';
import { createFeedback } from './createFeedback';

export const createCorrectRule = createAsyncThunk(
  `${ActivitiesSlice}/createCorrectRule`,
  async (payload: any) => {
    const { ruleId = `r:${guid()}`, isDefault = false } = payload;

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

    return rule;
  },
);

export const createIncorrectRule = createAsyncThunk(
  `${ActivitiesSlice}/createIncorrectRule`,
  async (payload: any, { dispatch }) => {
    const { ruleId = `r:${guid()}`, isDefault = false } = payload;

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

    return rule;
  },
);
