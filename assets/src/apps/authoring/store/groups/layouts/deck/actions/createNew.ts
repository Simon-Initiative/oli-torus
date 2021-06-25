import { createAsyncThunk } from '@reduxjs/toolkit';
import {
  DeckLayoutGroup,
  GroupsSlice,
  LayoutType,
  upsertGroup,
} from '../../../../../../delivery/store/features/groups/slice';

export const createNew = createAsyncThunk(
  `${GroupsSlice}/layouts/deck/createNew`,
  async (payload: any, { dispatch, getState }) => {
    const rootState = getState() as any; // any because this is shared and it's not the same reference

    // children should be SequenceEntry (TODO: typing)
    const children = payload.children || [];

    // update groups
    const group: DeckLayoutGroup = {
      id: Date.now(),
      type: 'group',
      layout: LayoutType.DECK,
      children,
    };

    await dispatch(upsertGroup({ group }));

    return group;
  },
);
