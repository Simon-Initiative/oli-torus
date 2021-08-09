import { createAsyncThunk } from '@reduxjs/toolkit';
import { clone } from 'utils/common';
import { GroupsSlice, upsertGroup } from '../../../../../../delivery/store/features/groups/slice';

export const updateSequenceItemFromActivity = createAsyncThunk(
  `${GroupsSlice}/updateSequenceItemFromActivity`,
  async (
    payload: {
      activity?: any;
      group?: any;
    },
    { dispatch },
  ) => {
    const { activity = {}, group = {} } = payload;
    const clonedGroup = clone(group);
    const sequenceEntry = clonedGroup.children.find(
      (entry: any) => entry.resourceId === activity.resourceId,
    );
    sequenceEntry.custom.sequenceName = activity.title;
    dispatch(upsertGroup({ group: clonedGroup }));
    // TODO: save it to a DB ?
    return group;
  },
);
