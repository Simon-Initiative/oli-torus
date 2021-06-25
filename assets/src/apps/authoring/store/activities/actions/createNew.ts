import { createAsyncThunk } from '@reduxjs/toolkit';
import {
  ActivitiesSlice,
  IActivity,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { createCorrectRule } from './rules';

export const createNew = createAsyncThunk(
  `${ActivitiesSlice}/createNew`,
  async (_, { dispatch, getState }) => {
    const rootState = getState() as any;
    // how to choose activity type? for now hard code to oli_adaptive?
    // should populate with a template
    const activity: IActivity = {
      type: 'activity',
      typeSlug: 'oli_adaptive',
      id: `new_activity_${Date.now()}`,
      title: 'New Activity',
      objectives: {}, // should populate with some from page?
      model: {
        authoring: {
          parts: [],
          rules: [],
        },
        custom: {},
        partsLayout: [],
      },
    };

    await dispatch(upsertActivity({ activity }));

    await dispatch(createCorrectRule({ isDefault: true, activityId: activity.id }));

    return activity;
  },
);
