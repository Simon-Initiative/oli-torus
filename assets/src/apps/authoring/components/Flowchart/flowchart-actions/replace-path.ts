import { createAsyncThunk, EntityId } from '@reduxjs/toolkit';
import { clone, cloneT } from '../../../../../utils/common';
import {
  IActivity,
  selectActivityById,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { saveActivity } from '../../../store/activities/actions/saveActivity';
import { FlowchartSlice } from '../../../store/flowchart/name';
import { AuthoringRootState } from '../../../store/rootReducer';
import { AllPaths } from '../paths/path-types';
import { isDestinationPath } from '../paths/path-utils';
import { validatePath } from '../paths/path-validation';
import { addFlowchartScreen } from './add-screen';

interface ReplacePathPayload {
  oldPathId: string;
  newPath: AllPaths;
  screenId: EntityId;
}

export const replacePath = createAsyncThunk(
  `${FlowchartSlice}/replacePath`,
  async (payload: ReplacePathPayload, { dispatch, getState }) => {
    const { oldPathId, newPath, screenId } = payload;
    if (isDestinationPath(newPath) && newPath.destinationScreenId === -1) {
      // This means the user wants to create a new screen that the path goes to.
      const result = await dispatch(addFlowchartScreen({ skipPathToNewScreen: true }));
      const newScreen = result.payload as IActivity;
      if (newScreen && newScreen.resourceId) {
        newPath.destinationScreenId = newScreen.resourceId;
      }
    }

    newPath.completed = validatePath(newPath);
    const rootState = getState() as AuthoringRootState;

    const screen = cloneT(selectActivityById(rootState, screenId));
    if (!screen) return;

    if (!screen.authoring?.flowchart) {
      screen.authoring = screen.authoring || {};
      screen.authoring.flowchart = {
        templateApplied: false,
        screenType: 'blank_screen',
        paths: [],
      };
    }

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

    dispatch(saveActivity({ activity: modifiedScreen, undoable: false, immediate: true }));
    await dispatch(upsertActivity({ activity: modifiedScreen }));
  },
);
