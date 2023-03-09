import { createAsyncThunk } from '@reduxjs/toolkit';

import { cloneT } from '../../../../../utils/common';

import ActivitiesSlice from '../../../../delivery/store/features/activities/name';
import {
  deleteActivity,
  IActivity,
  selectActivityById,
} from '../../../../delivery/store/features/activities/slice';
import { selectSequence } from '../../../../delivery/store/features/groups/selectors/deck';
import { selectCurrentGroup, upsertGroup } from '../../../../delivery/store/features/groups/slice';

import { bulkSaveActivity } from '../../../store/activities/actions/saveActivity';
import { savePage } from '../../../store/page/actions/savePage';
import { AuthoringRootState } from '../../../store/rootReducer';
import {
  AllPaths,
  createAlwaysGoToPath,
  createEndOfActivityPath,
  createUnknownPathWithDestination,
  getDownstreamScreenIds,
  setGoToAlwaysPath,
} from '../flowchart-path-utils';
import { selectDefaultDestination, selectPathsToScreen } from '../flowchart-selectors';

interface DeleteFlowchartScreenPayload {
  screenId: number;
}

export const deleteFlowchartScreen = createAsyncThunk(
  `${ActivitiesSlice}/addFlowchartScreen`,
  async (payload: DeleteFlowchartScreenPayload, { dispatch, getState }) => {
    const { screenId } = payload;
    const rootState = getState() as AuthoringRootState;
    const screen = selectActivityById(rootState, screenId);
    if (!screen) return;

    /* imagine:  [a] -> [b] -> [c]
      If we delete screen [b], we want [a] -> [c]
    */

    dispatch(removePathsToScreen(screen, rootState));
    dispatch(deleteActivity({ activityId: screenId }));
    dispatch(removeScreenGromGroup(screenId, rootState));

    await dispatch(savePage({ undoable: false }));
  },
);

const isActivity = (a: IActivity | undefined): a is IActivity => !!a;

const isNotToDestination = (destinationId: number) => (path: AllPaths) =>
  !('destinationScreenId' in path) || path.destinationScreenId !== destinationId;

const removeDestinationPaths =
  (screenId: number, nextScreenIds: number[]) => (original: IActivity) => {
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

    return activity;
  };

const removePathsToScreen = (screen: IActivity, rootState: AuthoringRootState) => {
  const inputPaths = selectPathsToScreen(rootState, screen.resourceId!);
  const screenIdsToModify = new Set(inputPaths.map((p) => p.sourceScreenId));
  const screensToModify = Array.from(screenIdsToModify)
    .map((id) => selectActivityById(rootState, id))
    .filter(isActivity);

  const nextScreenIds = getDownstreamScreenIds(screen);

  const modifiedScreens = screensToModify.map(
    removeDestinationPaths(screen.resourceId!, nextScreenIds),
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
