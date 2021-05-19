import { createSelector } from '@reduxjs/toolkit';
import { RootState } from 'apps/delivery/store/rootReducer';
import { selectAllActivities, selectCurrentActivityId } from '../../activities/slice';
import {
  findEldestAncestorInHierarchy,
  flattenHierarchy,
  getHierarchy,
  getSequenceLineage,
} from '../actions/sequence';
import { GroupsState, selectState } from '../slice';

export const selectSequence = createSelector(selectState, (state: GroupsState) => {
  if (state.currentGroupId === -1) {
    return [];
  }
  const currentGroup = state.entities[state.currentGroupId];
  return currentGroup ? currentGroup.children : [];
});

export const selectIsEnd = createSelector(selectSequence, (sequence) => {
  // check where we are currently
  // vs sequence end
  return false;
});

export const selectCurrentActivityTree = createSelector(
  (state: RootState) => {
    const sequence = selectSequence(state);
    const activities = selectAllActivities(state);
    const currentActivityId = selectCurrentActivityId(state);
    return [sequence, activities, currentActivityId];
  },
  ([sequence, activities, currentActivityId]) => {
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
