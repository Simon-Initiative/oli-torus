import { createAsyncThunk } from '@reduxjs/toolkit';
import { clone, cloneT } from '../../../../../utils/common';
import {
  selectAllActivities,
  upsertActivity,
} from '../../../../delivery/store/features/activities/slice';
import { selectSequence } from '../../../../delivery/store/features/groups/selectors/deck';
import {
  IGroup,
  selectCurrentGroup,
  upsertGroup,
} from '../../../../delivery/store/features/groups/slice';
import { saveActivity } from '../../../store/activities/actions/saveActivity';
import { selectAppMode } from '../../../store/app/slice';
import { reportAPIError } from '../../../store/flowchart/flowchart-slice';
import { FlowchartSlice } from '../../../store/flowchart/name';
import { savePage } from '../../../store/page/actions/savePage';
import { selectState as selectPageState } from '../../../store/page/slice';
import { AuthoringRootState } from '../../../store/rootReducer';
import { createAlwaysGoToPath, createExitPath } from '../paths/path-factories';
import { isUnknownPath } from '../paths/path-utils';
import { compareRules, generateRules } from '../rules/rule-compilation';
import { addFlowchartScreen } from './add-screen';
import { replacePath } from './replace-path';

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
      console.info('Verifying flowchart lesson data');

      await verifySingleEmptyRule(getState, dispatch);
      await verifyMaxAttempts(getState, dispatch);
      await verifyStartScreenExists(getState, dispatch);
      await verifyEndScreenExists(getState, dispatch);
      await verifyEndScreenIsLastScreen(getState, dispatch);
      await verifyEndScreenHasOnlyExitLessonPath(getState, dispatch);
      await verifyFinishMessageExists(getState, dispatch);
      await verifyAllRules(getState, dispatch);
    } catch (e) {
      dispatch(
        reportAPIError({
          error: JSON.stringify(e, Object.getOwnPropertyNames(e), 2),
          title: 'Could not validate lesson',
          message:
            'Something went wrong when attempting to validate this lesson. There is likely a problem with the lesson data that needs to be fixed before it can be delivered to learners. Please contact support for assistance.',
          failedActivity: null,
          info: null,
        }),
      );
      throw e;
    }
  },
);

// If there is a single "empty" path, turn it into an always-go-to path.
const verifySingleEmptyRule = async (getState: () => unknown, dispatch: any) => {
  const allActivities = selectAllActivities(getState() as AuthoringRootState);
  for (const activity of allActivities) {
    if (!activity.authoring?.flowchart?.paths) {
      continue;
    }

    if (activity.authoring?.flowchart?.paths.length !== 1) {
      continue;
    }

    const onlyPath = activity.authoring?.flowchart?.paths[0];

    if (isUnknownPath(onlyPath)) {
      await dispatch(
        replacePath({
          oldPathId: onlyPath.id,
          newPath: createAlwaysGoToPath(onlyPath.destinationScreenId),
          screenId: activity.id,
        }),
      );
    }
  }
};

// Our rules logic is set up for default 3-tries and you're done, so we want the maxAttempt default capped at 3 for scoring.
const verifyMaxAttempts = async (getState: () => unknown, dispatch: any) => {
  const allActivities = selectAllActivities(getState() as AuthoringRootState);
  for (const activity of allActivities) {
    if (!activity.content?.custom) {
      continue;
    }

    if (activity.content.custom.maxScore > 0 && !activity.content.custom?.maxAttempt) {
      const modifiedActivity = clone(activity);
      modifiedActivity.content.custom.maxAttempt = 3;
      dispatch(saveActivity({ activity: modifiedActivity, undoable: false, immediate: true }));
      await dispatch(upsertActivity({ activity: modifiedActivity }));
    }
  }
};

const verifyAllRules = async (getState: () => unknown, dispatch: any) => {
  const allActivities = selectAllActivities(getState() as AuthoringRootState);
  const sequence = selectSequence(getState() as AuthoringRootState);
  const defaultDestination =
    allActivities.find((s) => s.authoring?.flowchart?.screenType === 'end_screen')?.resourceId ||
    -1;

  for (const activity of allActivities) {
    if (!activity.authoring?.flowchart) {
      continue;
    }
    const calculatedRules = generateRules(activity, sequence, defaultDestination);
    if (!compareRules(calculatedRules.rules, activity.authoring?.rules || [])) {
      console.info("Rules didn't match for activity", activity.resourceId);
      const modifiedActivity = clone(activity);
      modifiedActivity.authoring.rules = calculatedRules.rules;
      modifiedActivity.authoring.variablesRequiredForEvaluation = calculatedRules.variables;
      dispatch(saveActivity({ activity: modifiedActivity, undoable: false, immediate: true }));
      await dispatch(upsertActivity({ activity: modifiedActivity }));
    }
  }
};

const verifyFinishMessageExists = async (getState: () => unknown, dispatch: any) => {
  const rootState = getState() as AuthoringRootState;
  const page = selectPageState(rootState);
  const customPropExists = !!page.custom;
  const logoutMessage = (page.custom?.logoutMessage || '').trim();

  if (customPropExists && logoutMessage.length === 0) {
    const newPage = cloneT(page);
    newPage.custom.logoutMessage = 'Thank you for completing this exercise.';
    await dispatch(savePage({ ...newPage, undoable: true }));
  }
};

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
    }
  }
};
