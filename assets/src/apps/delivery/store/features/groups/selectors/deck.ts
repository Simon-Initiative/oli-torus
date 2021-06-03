import { createSelector } from '@reduxjs/toolkit';
import { RootState } from 'apps/delivery/store/rootReducer';
import { ActivityState } from 'components/activities/types';
import { selectAllActivities, selectCurrentActivityId } from '../../activities/slice';
import {
  selectActivtyAttemptState,
  selectAll as selectAllActivityAttempts,
} from '../../attempt/slice';
import { getSequenceLineage } from '../actions/sequence';
import { GroupsState, selectState } from '../slice';

export const selectSequence = createSelector(selectState, (state: GroupsState) => {
  if (state.currentGroupId === -1) {
    return [];
  }
  const currentGroup = state.entities[state.currentGroupId];
  return currentGroup ? currentGroup.children : [];
});

export const selectCurrentActivityTree = createSelector(
  [selectSequence, selectAllActivities, selectCurrentActivityId],
  (sequence, activities, currentActivityId) => {
    const currentSequenceEntry = (sequence as any[]).find(
      (entry) => entry.custom.sequenceId === currentActivityId,
    );
    if (!currentSequenceEntry) {
      console.error(`Current Activity ${currentActivityId} not found in sequence!`);
      return null;
    }
    const lineage = getSequenceLineage(sequence as any[], currentSequenceEntry.custom.sequenceId);
    const tree = lineage.map((entry) =>
      (activities as any[]).find((a) => a.id === entry.custom.sequenceId),
    );
    // filtering out undefined, however TODO make sure they are loaded ahead of time!
    return tree.filter((t) => t);
  },
);

export const selectCurrentActivityTreeAttemptState = createSelector(
  (state: RootState) => {
    const currentTree = selectCurrentActivityTree(state);
    const attempts = currentTree?.map((t) => selectActivtyAttemptState(state, t.resourceId));
    return [currentTree, attempts];
  },
  ([currentTree, attempts]: [any[], ActivityState[]]) => {
    if (!currentTree?.length || !attempts?.length) {
      return;
    }
    const mappedTree = currentTree.map((activity) => {
      const attempt = attempts.find((a) => a.activityId === activity.resourceId);
      return attempt;
    });
    return mappedTree;
  },
);
