import { createAsyncThunk } from '@reduxjs/toolkit';
import guid from 'utils/guid';
import {
  ActivitiesSlice,
  IActivity,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { createSimpleText } from '../templates/simpleText';
import { createCorrectRule, createIncorrectRule } from './rules';

export const createNew = createAsyncThunk(
  `${ActivitiesSlice}/createNew`,
  async (_, { dispatch, getState }) => {
    const rootState = getState() as any;
    // how to choose activity type? for now hard code to oli_adaptive?
    // should populate with a template
    const activity: IActivity = {
      type: 'activity',
      typeSlug: 'oli_adaptive',
      id: `new_activity_${guid()}`,
      title: 'New Activity',
      objectives: {}, // should populate with some from page?
      model: {
        authoring: {
          parts: [],
          rules: [],
        },
        custom: {
          applyBtnFlag: false,
          applyBtnLabel: '',
          checkButtonLabel: 'Next',
          combineFeedback: false,
          customCssClass: '',
          facts: [],
          height: 600,
          lockCanvasSize: false,
          mainBtnLabel: '',
          maxAttempt: 0,
          maxScore: 0,
          negativeScoreAllowed: false,
          palette: {
            backgroundColor: 'rgba(255,255,255,0)',
            borderColor: 'rgba(255,255,255,0)',
            borderRadius: '',
            borderStyle: 'solid',
            borderWidth: '1px',
          },
          panelHeaderColor: 0,
          panelTitleColor: 0,
          showCheckBtn: true,
          trapStateScoreScheme: false,
          width: 800,
          x: 0,
          y: 0,
          z: 0,
        },
        partsLayout: [await createSimpleText('Hello World')],
      },
    };

    await dispatch(upsertActivity({ activity }));

    await dispatch(createCorrectRule({ isDefault: true, activityId: activity.id }));

    await dispatch(createIncorrectRule({ isDefault: true, activityId: activity.id }));

    return activity;
  },
);
