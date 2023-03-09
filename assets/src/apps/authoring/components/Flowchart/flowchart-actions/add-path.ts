import { createAsyncThunk, EntityId } from '@reduxjs/toolkit';
import { clone } from '../../../../../utils/common';
import ActivitiesSlice from '../../../../delivery/store/features/activities/name';
import {
  selectActivityById,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { saveActivity } from '../../../store/activities/actions/saveActivity';
import { AuthoringRootState } from '../../../store/rootReducer';
import { createEndOfActivityPath, createUnknownPathWithDestination } from '../paths/path-factories';

interface AddPathPayload {
  screenId: EntityId;
}

export const addPath = createAsyncThunk(
  `${ActivitiesSlice}/addPath`,
  async (payload: AddPathPayload, { dispatch, getState }) => {
    const { screenId } = payload;
    const rootState = getState() as AuthoringRootState;
    const screen = selectActivityById(rootState, screenId);
    if (!screen) return;
    const paths = screen.authoring?.flowchart?.paths;
    if (!paths) return;
    const newPaths = [...paths];
    newPaths.push(createUnknownPathWithDestination());
    const modifiedScreen = clone(screen);
    modifiedScreen.authoring.flowchart.paths = newPaths;

    await dispatch(upsertActivity({ activity: modifiedScreen }));
    dispatch(saveActivity({ activity: modifiedScreen, undoable: false, immediate: true }));
  },
);
