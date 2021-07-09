import { createAsyncThunk } from '@reduxjs/toolkit';
import { setCurrentActivityId } from '../../../../../../delivery/store/features/activities/slice';
import { findInSequence } from '../../../../../../delivery/store/features/groups/actions/sequence';
import { selectSequence } from '../../../../../../delivery/store/features/groups/selectors/deck';
import { GroupsSlice } from '../../../../../../delivery/store/features/groups/slice';

export const setCurrentActivityFromSequence = createAsyncThunk(
  `${GroupsSlice}/layouts/deck/setCurrentActivityFromSequence`,
  async (sequenceId: string, { dispatch, getState }) => {
    const state: any = getState();
    const sequence = selectSequence(state);
    if (!sequence) {
      throw new Error('Sequence not found');
    }
    const entry = findInSequence(sequence, sequenceId);
    if (!entry) {
      throw new Error('Entry not found');
    }
    return dispatch(setCurrentActivityId(entry.resourceId));
  },
);
