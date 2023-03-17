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
import { createEndOfActivityPath } from '../paths/path-factories';
import { generateRules } from '../rules/rule-compilation';

interface DeletePathPayload {
  pathId: string;
  screenId: EntityId;
}

export const deletePath = createAsyncThunk(
  `${FlowchartSlice}/deletePath`,
  async (payload: DeletePathPayload, { dispatch, getState }) => {
    const { pathId, screenId } = payload;
    const rootState = getState() as AuthoringRootState;
    const sequence = selectSequence(rootState);
    const screen = selectActivityById(rootState, screenId);
    if (!screen) return;
    const paths = screen.authoring?.flowchart?.paths;
    if (!paths) return;
    const newPaths = paths.filter((path) => path.id !== pathId);
    if (newPaths.length === 0) {
      newPaths.push(createEndOfActivityPath());
    }
    const modifiedScreen = clone(screen);
    modifiedScreen.authoring.flowchart.paths = newPaths;
    modifiedScreen.authoring.rules = generateRules(modifiedScreen, sequence);

    dispatch(saveActivity({ activity: modifiedScreen, undoable: false, immediate: true }));
    await dispatch(upsertActivity({ activity: modifiedScreen }));
  },
);
