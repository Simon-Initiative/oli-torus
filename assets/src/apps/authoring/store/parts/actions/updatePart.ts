import { createAsyncThunk } from '@reduxjs/toolkit';
import { selectActivityById } from 'apps/delivery/store/features/activities/slice';
import merge from 'lodash/merge';
import { clone } from 'utils/common';
import { saveActivity } from '../../activities/actions/saveActivity';
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

    // merge so that a partial of {custom: {x: 1, y: 1}} will not overwrite the entire custom object
    // TODO: payload.changes is Partial<Part>
    merge(partDef, payload.changes);

    await dispatch(saveActivity({ activity: activityClone }));
  },
);
