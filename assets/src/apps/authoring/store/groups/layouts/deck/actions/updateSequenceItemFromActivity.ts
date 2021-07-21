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
    const colnedGroup = clone(group);
    const sequencyEntry = colnedGroup.children.find(
      (entry: any) => entry.resourceId === activity.resourceId,
    );
    sequencyEntry.custom.sequenceName = activity.title;
    dispatch(upsertGroup({ group: colnedGroup }));
    // TODO: save it to a DB ?
    return group;
  },
);
