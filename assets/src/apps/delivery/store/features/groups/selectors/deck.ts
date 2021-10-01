import { createSelector } from '@reduxjs/toolkit';
import { RootState } from 'apps/delivery/store/rootReducer';
import { ActivityState } from 'components/activities/types';
import { selectAllActivities, selectCurrentActivityId } from '../../activities/slice';
import { selectActivtyAttemptState } from '../../attempt/slice';
import { getSequenceLineage } from '../actions/sequence';
import { GroupsState, selectState } from '../slice';

export const selectSequence = createSelector(selectState, (state: GroupsState) => {
  if (state.currentGroupId === -1) {
    return [];
  }
  const currentGroup = state.entities[state.currentGroupId];
  return currentGroup ? currentGroup.children : [];
});

export const selectCurrentSequenceId = createSelector(
  [selectSequence, selectCurrentActivityId],
  (sequence, currentActivityId) => {
    /* console.log('SELECT CURRENT SEQUENCE ID', { sequence, currentActivityId }); */
    return sequence.find((entry) => {
      // temp hack for authoring
      // TODO: rewire delivery to use resourceId instead of sequenceId
      let testId = entry.custom.sequenceId;
      if (typeof currentActivityId === 'number') {
        testId = entry.resourceId;
      }
      return testId === currentActivityId;
    })?.custom.sequenceId;
  },
);

export const selectCurrentActivityTree = createSelector(
  [selectSequence, selectAllActivities, selectCurrentSequenceId],
  (sequence, activities, currentSequenceId) => {
    const currentSequenceEntry = (sequence as any[]).find(
      (entry) => entry.custom.sequenceId === currentSequenceId,
    );
    if (!currentSequenceEntry) {
      // because this is a selector, might be undefined; stringify to display that
      // TODO: Logging System that can be turned off in prod and/or instrumented
      console.warn(`Current Activity ${JSON.stringify(currentSequenceId)} not found in sequence!`);
      return null;
    }
    const lineage = getSequenceLineage(sequence as any[], currentSequenceEntry.custom.sequenceId);
    const tree = lineage.map((entry) =>
      (activities as any[]).find((a) => a.resourceId === entry.resourceId),
    );
    /*  console.log('TREE', { lineage, activities }); */
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
