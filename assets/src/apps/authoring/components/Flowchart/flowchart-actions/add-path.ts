import { createAsyncThunk, EntityId } from '@reduxjs/toolkit';
import { clone } from '../../../../../utils/common';
import ActivitiesSlice from '../../../../delivery/store/features/activities/name';
import {
  selectActivityById,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { selectSequence } from '../../../../delivery/store/features/groups/selectors/deck';
import { saveActivity } from '../../../store/activities/actions/saveActivity';
import { FlowchartSlice } from '../../../store/flowchart/name';
import { AuthoringRootState } from '../../../store/rootReducer';
import { createEndOfActivityPath, createUnknownPathWithDestination } from '../paths/path-factories';
import { generateRules } from '../rules/rule-compilation';

interface AddPathPayload {
  screenId: EntityId;
}

export const addPath = createAsyncThunk(
  `${FlowchartSlice}/addPath`,
  async (payload: AddPathPayload, { dispatch, getState }) => {
    try {
      const { screenId } = payload;
      const rootState = getState() as AuthoringRootState;
      const sequence = selectSequence(rootState);
      const screen = selectActivityById(rootState, screenId);
      if (!screen) return null;
      const paths = screen.authoring?.flowchart?.paths;
      if (!paths) return null;
      const newPaths = [...paths];
      const newPath = createUnknownPathWithDestination();
      newPaths.push(newPath);
      const modifiedScreen = clone(screen);
      modifiedScreen.authoring.flowchart.paths = newPaths;
      modifiedScreen.authoring.rules = generateRules(modifiedScreen, sequence);

      dispatch(saveActivity({ activity: modifiedScreen, undoable: false, immediate: true }));
      await dispatch(upsertActivity({ activity: modifiedScreen }));

      return newPath;
    } catch (e) {
      console.error(e);
      throw e;
    }
  },
);
