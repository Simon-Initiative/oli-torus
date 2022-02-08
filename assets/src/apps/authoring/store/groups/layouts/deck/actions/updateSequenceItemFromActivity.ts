import { createAsyncThunk } from '@reduxjs/toolkit';
import {
  SequenceBank,
  SequenceEntry,
  SequenceEntryChild,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { clone } from 'utils/common';
import { IGroup, upsertGroup } from '../../../../../../delivery/store/features/groups/slice';
import GroupsSlice from '../../../../../../delivery/store/features/groups/name';

export const updateSequenceItemFromActivity = createAsyncThunk(
  `${GroupsSlice}/updateSequenceItemFromActivity`,
  async (
    payload: {
      activity?: any;
      group?: IGroup;
    },
    { dispatch },
  ) => {
    const { activity = {}, group = {} } = payload;
    const clonedGroup = clone(group);
    const sequenceEntry = clonedGroup.children.find(
      (entry: SequenceEntry<SequenceEntryChild>) => entry.resourceId === activity.resourceId,
    );
    sequenceEntry.custom.sequenceName = activity.title;
    dispatch(upsertGroup({ group: clonedGroup }));
    // TODO: save it to a DB ?
    return group;
  },
);

export const updateSequenceItem = createAsyncThunk(
  `${GroupsSlice}/updateSequenceItem`,
  async (
    payload: {
      sequence?: SequenceEntry<SequenceBank>;
      group?: IGroup;
    },
    { dispatch },
  ) => {
    const { sequence, group } = payload;
    const clonedGroup = clone(group);
    const sequenceEntry = clonedGroup.children.find(
      (entry: SequenceEntry<SequenceEntryChild>) => entry.resourceId === sequence?.resourceId,
    );
    sequenceEntry.custom = sequence?.custom;
    dispatch(upsertGroup({ group: clonedGroup }));
    // TODO: save it to a DB ?
    return group;
  },
);
