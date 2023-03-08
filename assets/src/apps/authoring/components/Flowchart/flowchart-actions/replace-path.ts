import { createAsyncThunk, EntityId } from '@reduxjs/toolkit';
import { clone } from '../../../../../utils/common';
import ActivitiesSlice from '../../../../delivery/store/features/activities/name';
import {
  selectActivityById,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { saveActivity } from '../../../store/activities/actions/saveActivity';
import { AuthoringRootState } from '../../../store/rootReducer';
import { AllPaths } from '../paths/path-types';
import { validatePath } from '../paths/path-validation';

interface ReplacePathPayload {
  oldPathId: string;
  newPath: AllPaths;
  screenId: EntityId;
}

export const replacePath = createAsyncThunk(
  `${ActivitiesSlice}/replacePath`,
  async (payload: ReplacePathPayload, { dispatch, getState }) => {
    const { oldPathId, newPath, screenId } = payload;
    newPath.completed = validatePath(newPath);
    const rootState = getState() as AuthoringRootState;
    const screen = selectActivityById(rootState, screenId);
    if (!screen) return;
    const paths = screen.authoring?.flowchart?.paths;
    if (!paths) return;
    const newPaths = paths.map((path) => {
      if (path.id === oldPathId) {
        return newPath;
      }
      return path;
    });
    const modifiedScreen = clone(screen);
    modifiedScreen.authoring.flowchart.paths = newPaths;

    await dispatch(upsertActivity({ activity: modifiedScreen }));
    dispatch(saveActivity({ activity: modifiedScreen, undoable: false, immediate: true }));
  },
);
