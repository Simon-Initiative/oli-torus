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
import { clone } from 'utils/common';
import { bulkSaveActivity } from '../../activities/actions/saveActivity';
import { PartsSlice } from '../slice';
export const addPart = createAsyncThunk(`${PartsSlice}/addPart`, (payload, { getState, dispatch }) => __awaiter(void 0, void 0, void 0, function* () {
    var _a, _b;
    const { activityId, newPartData } = payload;
    const rootState = getState(); // any because Activity slice is shared with delivery and things got funky with typescript...
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
        owner: ((_a = sequenceEntry === null || sequenceEntry === void 0 ? void 0 : sequenceEntry.custom) === null || _a === void 0 ? void 0 : _a.sequenceId) || '',
        inherited: false,
        // objectives: [],
    };
    activityClone.authoring.parts.push(partIdentifier);
    activityClone.content.partsLayout.push(newPartData);
    // need to add partIdentifier any sequence children
    const childrenToUpdate = [];
    const activityHierarchy = getHierarchy(sequence, (_b = sequenceEntry === null || sequenceEntry === void 0 ? void 0 : sequenceEntry.custom) === null || _b === void 0 ? void 0 : _b.sequenceId);
    if (activityHierarchy.length) {
        const flattenedHierarchy = flattenHierarchy(activityHierarchy);
        flattenedHierarchy.forEach((child) => {
            const childActivity = selectActivityById(rootState, child.resourceId);
            const childClone = clone(childActivity);
            childClone.authoring.parts.push(Object.assign(Object.assign({}, partIdentifier), { inherited: true }));
            childrenToUpdate.push(childClone);
        });
    }
    const activitiesToUpdate = [activityClone, ...childrenToUpdate];
    /* console.log('adding new part', { newPartData, activityClone, currentSequence }); */
    dispatch(bulkSaveActivity({ activities: activitiesToUpdate }));
}));
//# sourceMappingURL=addPart.js.map