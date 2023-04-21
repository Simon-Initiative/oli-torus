import { EntityId, createAsyncThunk } from '@reduxjs/toolkit';
import {
  selectActivityById,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { saveActivity } from '../../../store/activities/actions/saveActivity';
import { FlowchartSlice } from '../../../store/flowchart/name';
import { AuthoringRootState } from '../../../store/rootReducer';
import { Template } from '../template-types';
import { applyTemplateToActivity } from '../template-utils';
import { reportAPIError } from '../../../store/flowchart/flowchart-slice';

interface ApplyTemplatePayload {
  screenId: EntityId;
  template: Template;
}

export const applyTemplate = createAsyncThunk(
  `${FlowchartSlice}/applyTemplate`,
  async (payload: ApplyTemplatePayload, { dispatch, getState }) => {
    const { screenId, template } = payload;
    const rootState = getState() as AuthoringRootState;
    const screen = selectActivityById(rootState, screenId);

    try {
      if (!screen) return null;

      const modifiedScreen = applyTemplateToActivity(screen, template);
      if (!modifiedScreen) return null;

      dispatch(saveActivity({ activity: modifiedScreen, undoable: false, immediate: true }));
      await dispatch(upsertActivity({ activity: modifiedScreen }));
      return modifiedScreen;
    } catch (e) {
      dispatch(
        reportAPIError({
          error: JSON.stringify(e, Object.getOwnPropertyNames(e), 2),
          title: 'Could not apply template to screen',
          message:
            'Something went wrong when attempting to apply a template to a screen. Please try again.',
          failedActivity: screen,
          info: null,
        }),
      );
      throw e;
    }
  },
);
