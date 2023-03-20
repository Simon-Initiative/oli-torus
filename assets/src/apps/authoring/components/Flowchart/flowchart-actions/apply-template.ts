import { createAsyncThunk, EntityId } from '@reduxjs/toolkit';
import {
  selectActivityById,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { saveActivity } from '../../../store/activities/actions/saveActivity';
import { FlowchartSlice } from '../../../store/flowchart/name';
import { AuthoringRootState } from '../../../store/rootReducer';
import { Template } from '../template-types';
import { applyTemplateToActivity } from '../template-utils';

interface ApplyTemplatePayload {
  screenId: EntityId;
  template: Template;
}

export const applyTemplate = createAsyncThunk(
  `${FlowchartSlice}/applyTemplate`,
  async (payload: ApplyTemplatePayload, { dispatch, getState }) => {
    try {
      const { screenId, template } = payload;
      const rootState = getState() as AuthoringRootState;
      const screen = selectActivityById(rootState, screenId);
      if (!screen) return null;

      const modifiedScreen = applyTemplateToActivity(screen, template);
      if (!modifiedScreen) return null;

      dispatch(saveActivity({ activity: modifiedScreen, undoable: false, immediate: true }));
      await dispatch(upsertActivity({ activity: modifiedScreen }));
      return modifiedScreen;
    } catch (e) {
      console.error(e);
      throw e;
    }
  },
);
