import { createSelector } from '@reduxjs/toolkit';
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
