import { createAsyncThunk } from '@reduxjs/toolkit';
import { IActivity, selectActivityById } from 'apps/delivery/store/features/activities/slice';
import {
  findInSequenceByResourceId,
  flattenHierarchy,
  getHierarchy,
} from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import merge from 'lodash/merge';
import { clone } from 'utils/common';
import { bulkSaveActivity, saveActivity } from '../../activities/actions/saveActivity';
import { PartsSlice } from '../slice';

export const updatePart = createAsyncThunk(
  `${PartsSlice}/updatePart`,
  async (payload: { activityId: string; partId: string; changes: any }, { getState, dispatch }) => {
    const rootState = getState() as any; // any because Activity slice is shared with delivery and things got funky with typescript...
    const activity = selectActivityById(rootState, payload.activityId);
    if (!activity) {
      throw new Error(`Activity: ${payload.activityId} not found!`);
    }
    const activityClone = clone(activity);
    const partDef = activityClone.content.partsLayout.find(
      (part: any) => part.id === payload.partId,
    );
    if (!partDef) {
      throw new Error(`Part: ${payload.partId} not found in Activity: ${payload.activityId}`);
    }

    if (payload.changes.id) {
      // need to also update the authoring parts list
      const authorPart = activityClone.authoring.parts.find(
        (part: any) => part.id === payload.partId && !part.inherited,
      );
      const sequence = selectSequence(rootState);
      const sequenceEntry = findInSequenceByResourceId(sequence, activityClone.id);
      const activitySequenceId = sequenceEntry?.custom.sequenceId;
      if (!authorPart) {
        // this shouldn't happen, but maybe it was missing?? add it
        activityClone.authoring.parts.push({
          id: payload.changes.id,
          inherited: false,
          type: partDef.type,
          owner: activitySequenceId,
        });
      } else {
        authorPart.id = payload.changes.id;
      }

      // if this item has any children in the sequence, update them too
      if (sequenceEntry) {
        const hierarchy = getHierarchy(sequence, activitySequenceId);
        const allInvolved = flattenHierarchy(hierarchy);
        const activitiesToUpdate: IActivity[] = [];
        allInvolved.forEach((item: any) => {
          const activity = selectActivityById(rootState, item.resourceId);
          if (activity) {
            const cloned = clone(activity);
            const part = cloned.authoring.parts.find(
              (part: any) => part.id === payload.partId && part.owner === activitySequenceId,
            );
            if (part) {
              part.id = payload.changes.id;
              activitiesToUpdate.push(cloned);
            }
          }
        });
        if (activitiesToUpdate.length) {
          await dispatch(bulkSaveActivity({ activities: activitiesToUpdate }));
        }
      }
    }

    // merge so that a partial of {custom: {x: 1, y: 1}} will not overwrite the entire custom object
    // TODO: payload.changes is Partial<Part>
    merge(partDef, payload.changes);

    await dispatch(saveActivity({ activity: activityClone }));
  },
);
