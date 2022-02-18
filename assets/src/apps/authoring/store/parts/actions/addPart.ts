import { createAsyncThunk } from '@reduxjs/toolkit';
import { selectActivityById } from 'apps/delivery/store/features/activities/slice';
import {
  findInSequenceByResourceId,
  flattenHierarchy,
  getHierarchy,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import { clone } from 'utils/common';
import { bulkSaveActivity } from '../../activities/actions/saveActivity';
import { PartsSlice } from '../name';

export const addPart = createAsyncThunk(
  `${PartsSlice}/addPart`,
  async (payload: { activityId: number; newPartData: any }, { getState, dispatch }) => {
    const { activityId, newPartData } = payload;
    const rootState = getState() as any; // any because Activity slice is shared with delivery and things got funky with typescript...
    const activity = selectActivityById(rootState, activityId);
    if (!activity) {
      throw new Error(`Activity: ${activityId} not found!`);
    }
    const activityClone = clone(activity);
    const sequence = selectSequence(rootState);
    const sequenceEntry = findInSequenceByResourceId(sequence, activityClone.resourceId);
    const partIdentifier = {
      id: newPartData.id,
      type: newPartData.type,
      owner: sequenceEntry?.custom?.sequenceId || '',
      inherited: false,
      // objectives: [],
    };
    if (newPartData.type !== 'janus-text-flow' && newPartData.type !== 'janus-image') {
      activityClone.authoring.parts.push(partIdentifier);
    }
    activityClone.content.partsLayout.push(newPartData);

    // need to add partIdentifier any sequence children
    const childrenToUpdate: any[] = [];
    if (newPartData.type !== 'janus-text-flow' && newPartData.type !== 'janus-image') {
      const activityHierarchy = getHierarchy(sequence, sequenceEntry?.custom?.sequenceId);
      if (activityHierarchy.length) {
        const flattenedHierarchy = flattenHierarchy(activityHierarchy);
        flattenedHierarchy.forEach((child) => {
          const childActivity = selectActivityById(rootState, child.resourceId as number);
          const childClone = clone(childActivity);
          childClone.authoring.parts.push({ ...partIdentifier, inherited: true });
          childrenToUpdate.push(childClone);
        });
      }
    }

    const activitiesToUpdate = [activityClone, ...childrenToUpdate];

    /* console.log('adding new part', { newPartData, activityClone, currentSequence }); */
    dispatch(bulkSaveActivity({ activities: activitiesToUpdate, undoable: true }));
  },
);
