import { createAsyncThunk } from '@reduxjs/toolkit';
import guid from 'utils/guid';
import { ActivitiesSlice } from '../../../../delivery/store/features/activities/slice';
import { createSimpleText } from '../templates/simpleText';

export const createFeedback = createAsyncThunk(
  `${ActivitiesSlice}/createFeedback`,
  async (payload: { msg?: string }) => {
    const { msg = 'Incorrect, please try again.' } = payload;

    // feedback has a similar model to an activity but is *not* an activity
    const feedbackModel = {
      custom: {
        applyBtnFlag: false,
        applyBtnLabel: 'Show Solution',
        mainBtnLabel: 'Next',
        panelTitleColor: 16777215,
        panelHeaderColor: 10027008,
        lockCanvasSize: true,
        width: 350.0,
        palette: {
          fillColor: 1.6777215e7,
          fillAlpha: 0.0,
          lineColor: 1.6777215e7,
          lineAlpha: 0.0,
          lineThickness: 0.1,
          lineStyle: 0.0,
        },
        rules: [],
        facts: [],
        height: 100.0,
      },
      partsLayout: [await createSimpleText(msg)],
    };

    const feedbackAction = {
      type: 'feedback',
      params: {
        id: `a_f_${guid()}`,
        feedback: feedbackModel,
      },
    };

    return feedbackAction;
  },
);
