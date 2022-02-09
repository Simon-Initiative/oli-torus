import { createAsyncThunk } from '@reduxjs/toolkit';
import {
  DeckLayoutGroup,
  LayoutType,
  upsertGroup,
} from '../../../../../../delivery/store/features/groups/slice';
import GroupsSlice from '../../../../../../delivery/store/features/groups/name';

export const createNew = createAsyncThunk(
  `${GroupsSlice}/layouts/deck/createNew`,
  async (payload: any, { dispatch, getState }) => {
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
