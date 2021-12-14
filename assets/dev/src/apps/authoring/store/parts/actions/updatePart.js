var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { createAsyncThunk } from '@reduxjs/toolkit';
import { selectActivityById } from 'apps/delivery/store/features/activities/slice';
import { findInSequenceByResourceId, flattenHierarchy, getHierarchy, } from 'apps/delivery/store/features/groups/actions/sequence';
import { selectSequence } from 'apps/delivery/store/features/groups/selectors/deck';
import merge from 'lodash/merge';
import { clone } from 'utils/common';
import { bulkSaveActivity, saveActivity } from '../../activities/actions/saveActivity';
import { PartsSlice } from '../slice';
export const updatePart = createAsyncThunk(`${PartsSlice}/updatePart`, (payload, { getState, dispatch }) => __awaiter(void 0, void 0, void 0, function* () {
    const rootState = getState(); // any because Activity slice is shared with delivery and things got funky with typescript...
    const activity = selectActivityById(rootState, payload.activityId);
    if (!activity) {
        throw new Error(`Activity: ${payload.activityId} not found!`);
    }
    const activityClone = clone(activity);
    const partDef = activityClone.content.partsLayout.find((part) => part.id === payload.partId);
    if (!partDef) {
        throw new Error(`Part: ${payload.partId} not found in Activity: ${payload.activityId}`);
    }
    if (payload.changes.id) {
        // need to also update the authoring parts list
        const authorPart = activityClone.authoring.parts.find((part) => part.id === payload.partId && !part.inherited);
        const sequence = selectSequence(rootState);
        const sequenceEntry = findInSequenceByResourceId(sequence, activityClone.id);
        const activitySequenceId = sequenceEntry === null || sequenceEntry === void 0 ? void 0 : sequenceEntry.custom.sequenceId;
        if (!authorPart) {
            // this shouldn't happen, but maybe it was missing?? add it
            activityClone.authoring.parts.push({
                id: payload.changes.id,
                inherited: false,
                type: partDef.type,
                owner: activitySequenceId,
            });
        }
        else {
            authorPart.id = payload.changes.id;
        }
        // if this item has any children in the sequence, update them too
        if (sequenceEntry) {
            const hierarchy = getHierarchy(sequence, activitySequenceId);
            const allInvolved = flattenHierarchy(hierarchy);
            const activitiesToUpdate = [];
            allInvolved.forEach((item) => {
                const activity = selectActivityById(rootState, item.resourceId);
                if (activity) {
                    const cloned = clone(activity);
                    const part = cloned.authoring.parts.find((part) => part.id === payload.partId && part.owner === activitySequenceId);
                    if (part) {
                        part.id = payload.changes.id;
                        activitiesToUpdate.push(cloned);
                    }
                }
            });
            if (activitiesToUpdate.length) {
                yield dispatch(bulkSaveActivity({ activities: activitiesToUpdate }));
            }
        }
    }
    // merge so that a partial of {custom: {x: 1, y: 1}} will not overwrite the entire custom object
    // TODO: payload.changes is Partial<Part>
    merge(partDef, payload.changes);
    yield dispatch(saveActivity({ activity: activityClone }));
}));
//# sourceMappingURL=updatePart.js.map