import { createAsyncThunk, EntityId } from '@reduxjs/toolkit';
import { cloneT } from '../../../../../utils/common';
import {
  selectActivityById,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { saveActivity } from '../../../store/activities/actions/saveActivity';
import { FlowchartSlice } from '../../../store/flowchart/name';
import { AuthoringRootState } from '../../../store/rootReducer';
import { createUnknownPathWithDestination } from '../paths/path-factories';

interface AddPathPayload {
  screenId: EntityId;
}

export const addPath = createAsyncThunk(
  `${FlowchartSlice}/addPath`,
  async (payload: AddPathPayload, { dispatch, getState }) => {
    try {
      const { screenId } = payload;
      const rootState = getState() as AuthoringRootState;

      const screen = cloneT(selectActivityById(rootState, screenId));
      if (!screen) return null;
      if (!screen.authoring?.flowchart) {
        screen.authoring = screen.authoring || {};
        screen.authoring.flowchart = {
          templateApplied: false,
          screenType: 'blank_screen',
          paths: [],
        };
      }
      const paths = screen.authoring?.flowchart?.paths;
      if (!paths) return null;
      const newPaths = [...paths];
      const newPath = createUnknownPathWithDestination();
      newPaths.push(newPath);
      screen.authoring.flowchart.paths = newPaths;

      dispatch(saveActivity({ activity: screen, undoable: false, immediate: true }));
      await dispatch(upsertActivity({ activity: screen }));

      return newPath;
    } catch (e) {
      console.error(e);
      throw e;
    }
  },
);
