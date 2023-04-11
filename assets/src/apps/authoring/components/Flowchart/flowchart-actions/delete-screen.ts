import { createAsyncThunk } from '@reduxjs/toolkit';

import { cloneT } from '../../../../../utils/common';

import ActivitiesSlice from '../../../../delivery/store/features/activities/name';
import {
  deleteActivity,
  IActivity,
  selectActivityById,
  selectAllActivities,
} from '../../../../delivery/store/features/activities/slice';
import {
  SequenceEntry,
  SequenceEntryChild,
} from '../../../../delivery/store/features/groups/actions/sequence';
import { selectSequence } from '../../../../delivery/store/features/groups/selectors/deck';
import { selectCurrentGroup, upsertGroup } from '../../../../delivery/store/features/groups/slice';

import { bulkSaveActivity } from '../../../store/activities/actions/saveActivity';
import { FlowchartSlice } from '../../../store/flowchart/name';
import { savePage } from '../../../store/page/actions/savePage';
import { AuthoringRootState } from '../../../store/rootReducer';
import { selectPathsToScreen } from '../flowchart-selectors';
import {
  createAlwaysGoToPath,
  createEndOfActivityPath,
  createUnknownPathWithDestination,
} from '../paths/path-factories';
import { AllPaths } from '../paths/path-types';
import { getDownstreamScreenIds } from '../paths/path-utils';
import { generateRules } from '../rules/rule-compilation';

interface DeleteFlowchartScreenPayload {
  screenId: number;
}

export const deleteFlowchartScreen = createAsyncThunk(
  `${FlowchartSlice}/addFlowchartScreen`,
  async (payload: DeleteFlowchartScreenPayload, { dispatch, getState }) => {
    const { screenId } = payload;
    const rootState = getState() as AuthoringRootState;
    const screen = selectActivityById(rootState, screenId);
    const allScreens = selectAllActivities(rootState);
    if (!screen) return;
    if (allScreens.length <= 1) return; // Don't delete the last screen

    /* imagine:  [a] -> [b] -> [c]
      If we delete screen [b], we want [a] -> [c]
    */

    dispatch(removePathsToScreen(screen, rootState));
    dispatch(deleteActivity({ activityId: screenId }));
    dispatch(removeScreenGromGroup(screenId, rootState));
    dispatch(savePage({ undoable: false, immiediate: true }));
  },
);

const isActivity = (a: IActivity | undefined): a is IActivity => !!a;

const isNotToDestination = (destinationId: number) => (path: AllPaths) =>
  !('destinationScreenId' in path) || path.destinationScreenId !== destinationId;

const removeDestinationPaths =
  (
    screenId: number,
    nextScreenIds: number[],
    sequence: SequenceEntry<SequenceEntryChild>[],
    defaultDestination: number,
  ) =>
  (original: IActivity) => {
    const activity = cloneT(original);
    if (!activity?.authoring?.flowchart) return original;

    // Go from
    // [original] -> [screenId] -> [nextScreenIds] (maybe several)
    // to
    // [original] -> [nextScreenIds] (maybe several)

    // First, remove the middle one
    activity.authoring.flowchart.paths = activity.authoring.flowchart.paths.filter(
      isNotToDestination(screenId),
    );

    // Special Case: Can we create an always-go-to path instead of unknown paths?
    const canBeAlwaysPath =
      nextScreenIds.length === 1 && activity.authoring.flowchart.paths.length === 0;

    // Then add in the new paths
    nextScreenIds.forEach((nextScreenId) => {
      if (canBeAlwaysPath) {
        activity.authoring?.flowchart?.paths.push(createAlwaysGoToPath(nextScreenId));
      } else {
        activity.authoring?.flowchart?.paths.push(createUnknownPathWithDestination(nextScreenId));
      }
    });

    if (activity.authoring.flowchart.paths.length === 0) {
      // If there aren't any next paths, add in an end of activity
      activity.authoring.flowchart.paths = [createEndOfActivityPath()];
    }

    const { rules, variables } = generateRules(activity, sequence, defaultDestination);
    activity.authoring.rules = rules;
    activity.authoring.variablesRequiredForEvaluation = variables;

    return activity;
  };

const removePathsToScreen = (screen: IActivity, rootState: AuthoringRootState) => {
  const inputPaths = selectPathsToScreen(rootState, screen.resourceId!);
  const sequence = selectSequence(rootState);
  const all = selectAllActivities(rootState);
  const screenIdsToModify = new Set(inputPaths.map((p) => p.sourceScreenId));
  const screensToModify = Array.from(screenIdsToModify)
    .map((id) => selectActivityById(rootState, id))
    .filter(isActivity);

  const nextScreenIds = getDownstreamScreenIds(screen);
  const endScreen = all.find((s) => s.authoring?.flowchart?.screenType === 'end_screen');

  const modifiedScreens = screensToModify.map(
    removeDestinationPaths(
      screen.resourceId!,
      nextScreenIds,
      sequence,
      endScreen?.resourceId || -1,
    ),
  );

  return bulkSaveActivity({ activities: modifiedScreens });
};

const removeScreenGromGroup = (screenId: number, rootState: AuthoringRootState) => {
  const currentGroup = selectCurrentGroup(rootState);
  const sequence = selectSequence(rootState);
  const newGroup = {
    ...currentGroup,
    children: sequence.filter((seq) => seq.resourceId !== screenId),
  };
  return upsertGroup({ group: newGroup });
};
