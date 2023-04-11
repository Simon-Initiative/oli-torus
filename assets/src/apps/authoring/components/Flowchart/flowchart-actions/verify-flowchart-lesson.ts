import { createAsyncThunk } from '@reduxjs/toolkit';
import { FlowchartSlice } from '../../../store/flowchart/name';
import { AuthoringRootState } from '../../../store/rootReducer';
import { selectAppMode } from '../../../store/app/slice';
import { selectSequence } from '../../../../delivery/store/features/groups/selectors/deck';
import {
  selectAllActivities,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { addFlowchartScreen } from './add-screen';
import { flattenHierarchy } from '../../../../delivery/store/features/groups/actions/sequence';
import { clone } from '../../../../../utils/common';
import {
  IGroup,
  selectCurrentGroup,
  upsertGroup,
} from '../../../../delivery/store/features/groups/slice';

import { savePage } from '../../../store/page/actions/savePage';
import { saveActivity } from '../../../store/activities/actions/saveActivity';
import { createExitPath } from '../paths/path-factories';

interface VerifyFlowchartLessonPayload {}

export const verifyFlowchartLesson = createAsyncThunk(
  `${FlowchartSlice}/verifyFlowchartLesson`,
  async (payload: VerifyFlowchartLessonPayload, { dispatch, getState }) => {
    try {
      const rootState = getState() as AuthoringRootState;
      const appMode = selectAppMode(rootState);
      if (appMode !== 'flowchart') {
        throw new Error('verifyFlowchartLesson can only be called when appMode is flowchart');
      }

      // Some things a flowchart lesson requires:
      // 1. A starting screen
      // 2. An end of lesson screen
      // 3. The end screen must be the last screen in the sequence
      // 4. The end screen must only have an exit-lesson path.
      verifyStartScreenExists(getState, dispatch);
      verifyEndScreenExists(getState, dispatch);
      verifyEndScreenIsLastScreen(getState, dispatch);
      verifyEndScreenHasOnlyExitLessonPath(getState, dispatch);
    } catch (e) {
      console.error(e);
      throw e;
    }
  },
);

const verifyStartScreenExists = async (getState: () => unknown, dispatch: any) => {
  const rootState = getState() as AuthoringRootState;
  const sequence = selectSequence(rootState);
  const screens = selectAllActivities(rootState);

  const firstActivity = sequence.find(
    (c) => !!c.resourceId && c.authoring?.flowchart?.screenType !== 'end_screen',
  );
  const firstScreen = screens.find((s) => s.resourceId === firstActivity?.resourceId);
  if (!firstScreen) {
    console.info('Creating welcome screen');
    await dispatch(
      addFlowchartScreen({
        title: 'Welcome Screen',
        screenType: 'welcome_screen',
      }),
    );
  }
};

const verifyEndScreenExists = async (getState: () => unknown, dispatch: any) => {
  const rootState = getState() as AuthoringRootState;
  const screens = selectAllActivities(rootState);
  const endScreen = screens.find((s) => s.authoring?.flowchart?.screenType === 'end_screen');

  if (!endScreen) {
    console.info('Creating end screen');
    await dispatch(
      addFlowchartScreen({
        title: 'End of Lesson',
        screenType: 'end_screen',
        skipPathToNewScreen: true,
      }),
    );
  }
};

const verifyEndScreenIsLastScreen = async (getState: () => unknown, dispatch: any) => {
  const rootState = getState() as AuthoringRootState;
  const sequence = selectSequence(rootState);
  const screens = selectAllActivities(rootState);
  const endScreen = screens.find((s) => s.authoring?.flowchart?.screenType === 'end_screen');
  const index = sequence.findIndex((s) => s.resourceId === endScreen?.resourceId);

  if (index !== sequence.length - 1) {
    console.info('Moving end screen to the end of the sequence');
    const newSequence = [...sequence];
    const endSeq = newSequence.splice(index, 1);
    newSequence.push(endSeq[0]);
    const currentGroup = selectCurrentGroup(rootState);
    if (currentGroup) {
      const newGroup = { ...currentGroup, children: newSequence } as IGroup;
      dispatch(upsertGroup({ group: newGroup }));
      await dispatch(savePage({ undoable: false }));
    }
  }
};

const verifyEndScreenHasOnlyExitLessonPath = async (getState: () => unknown, dispatch: any) => {
  const rootState = getState() as AuthoringRootState;
  const screens = selectAllActivities(rootState);
  for (const screen of screens) {
    if (screen.authoring?.flowchart?.screenType === 'end_screen') {
      // An end screen should have a single path that exits the lesson.
      const paths = screen.authoring?.flowchart?.paths;
      if (paths.length !== 1 || paths[0].type !== 'exit-activity') {
        console.info('Replacing the paths in the end-screen with a single exit path');
        const modifiedScreen = clone(screen);
        modifiedScreen.authoring.flowchart.paths = [createExitPath()];

        dispatch(saveActivity({ activity: modifiedScreen, undoable: false, immediate: true }));
        await dispatch(upsertActivity({ activity: modifiedScreen }));
      }
    } else {
      // All other screens should NOT have an exit lesson path.
    }
  }
};
