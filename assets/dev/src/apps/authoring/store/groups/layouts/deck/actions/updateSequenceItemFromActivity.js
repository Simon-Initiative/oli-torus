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
import { GroupsSlice, upsertGroup, } from '../../../../../../delivery/store/features/groups/slice';
export const updateSequenceItemFromActivity = createAsyncThunk(`${GroupsSlice}/updateSequenceItemFromActivity`, (payload, { dispatch }) => __awaiter(void 0, void 0, void 0, function* () {
    const { activity = {}, group = {} } = payload;
    const clonedGroup = clone(group);
    const sequenceEntry = clonedGroup.children.find((entry) => entry.resourceId === activity.resourceId);
    sequenceEntry.custom.sequenceName = activity.title;
    dispatch(upsertGroup({ group: clonedGroup }));
    // TODO: save it to a DB ?
    return group;
}));
export const updateSequenceItem = createAsyncThunk(`${GroupsSlice}/updateSequenceItem`, (payload, { dispatch }) => __awaiter(void 0, void 0, void 0, function* () {
    const { sequence, group } = payload;
    const clonedGroup = clone(group);
    const sequenceEntry = clonedGroup.children.find((entry) => entry.resourceId === (sequence === null || sequence === void 0 ? void 0 : sequence.resourceId));
    sequenceEntry.custom = sequence === null || sequence === void 0 ? void 0 : sequence.custom;
    dispatch(upsertGroup({ group: clonedGroup }));
    // TODO: save it to a DB ?
    return group;
}));
//# sourceMappingURL=updateSequenceItemFromActivity.js.map