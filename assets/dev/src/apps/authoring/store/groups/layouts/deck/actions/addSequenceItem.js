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
import { clone } from 'utils/common';
import { findInHierarchy, flattenHierarchy, getHierarchy, } from '../../../../../../delivery/store/features/groups/actions/sequence';
import { GroupsSlice, upsertGroup } from '../../../../../../delivery/store/features/groups/slice';
export const addSequenceItem = createAsyncThunk(`${GroupsSlice}/addSequenceItem`, (payload, { dispatch }) => __awaiter(void 0, void 0, void 0, function* () {
    const { sequence = [], group = {}, item = {}, parentId = undefined, siblingId = undefined, } = payload;
    let sequenceItems = [...sequence];
    if (parentId) {
        const parentItem = sequenceItems.find((i) => i.activitySlug === parentId);
        if (parentItem) {
            parentItem.custom = parentItem.custom || {};
            const parentIndex = sequenceItems.indexOf(parentItem);
            // it should already be set?
            item.custom.layerRef = parentItem.activitySlug;
            // need to add it *after* any other children
            // in order to do that, need to stick it in heirarchy order
            const hierarchy = getHierarchy(sequenceItems);
            const parentInHierarchy = findInHierarchy(hierarchy, parentId);
            if (!parentInHierarchy) {
                console.warn('Hierarchy', { hierarchy });
                throw new Error(`Couldn't find ${parentId} in heirarchy, shouldn't be possible.`);
            }
            if (siblingId) {
                const siblingEntryIndex = parentInHierarchy.children.findIndex((entry) => entry.activitySlug === siblingId);
                if (siblingEntryIndex < 0) {
                    console.warn(`couldn't find sibling ${siblingId}, shouldn't be possible`);
                    // just push at the end then
                    parentInHierarchy.children.push(item);
                }
                else {
                    parentInHierarchy.children.splice(siblingEntryIndex + 1, 0, item);
                }
            }
            else {
                parentInHierarchy.children.push(item);
            }
            // then once done need to flatten it out again
            sequenceItems = flattenHierarchy(hierarchy);
        }
    }
    else {
        if (siblingId) {
            const siblingEntryIndex = sequenceItems.findIndex((entry) => entry.activitySlug === siblingId);
            if (siblingEntryIndex < 0) {
                console.warn(`couldn't find sibling ${siblingId}, shouldn't be possible`);
                // just push at the end then
                sequenceItems.push(item);
            }
            else {
                sequenceItems.splice(siblingEntryIndex + 1, 0, item);
            }
        }
        else {
            sequenceItems.push(item);
        }
    }
    const newGroup = clone(group);
    newGroup.children = sequenceItems;
    dispatch(upsertGroup({ group: newGroup }));
    // TODO: save it to a DB ?
    return newGroup;
}));
//# sourceMappingURL=addSequenceItem.js.map