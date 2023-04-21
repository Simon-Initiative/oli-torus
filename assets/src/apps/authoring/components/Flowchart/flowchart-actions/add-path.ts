import { EntityId, createAsyncThunk } from '@reduxjs/toolkit';
import { cloneT } from '../../../../../utils/common';
import {
  selectActivityById,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { saveActivity } from '../../../store/activities/actions/saveActivity';
import { FlowchartSlice } from '../../../store/flowchart/name';
import { AuthoringRootState } from '../../../store/rootReducer';
import { createEndOfActivityPath, createUnknownPathWithDestination } from '../paths/path-factories';
import { reportAPIError } from '../../../store/flowchart/flowchart-slice';

interface AddPathPayload {
  screenId: EntityId;
}

export const addPath = createAsyncThunk(
  `${FlowchartSlice}/addPath`,
  async (payload: AddPathPayload, { dispatch, getState }) => {
    const { screenId } = payload;
    const rootState = getState() as AuthoringRootState;
    const screen = cloneT(selectActivityById(rootState, screenId));

    try {
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

      const newPath = createEndOfActivityPath();
      const newPaths = [...paths, newPath];
      screen.authoring.flowchart.paths = newPaths;

      dispatch(saveActivity({ activity: screen, undoable: false, immediate: true }));
      await dispatch(upsertActivity({ activity: screen }));

      return newPath;
    } catch (e) {
      dispatch(
        reportAPIError({
          error: JSON.stringify(e, Object.getOwnPropertyNames(e), 2),
          title: 'Could not add path',
          message: 'This path could not be added. Please try again.',
          failedActivity: screen,
          info: null,
        }),
      );
      throw e;
    }
  },
);
