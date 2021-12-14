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
import { setCurrentActivityId } from '../../../../../../delivery/store/features/activities/slice';
import { findInSequence } from '../../../../../../delivery/store/features/groups/actions/sequence';
import { selectSequence } from '../../../../../../delivery/store/features/groups/selectors/deck';
import { GroupsSlice } from '../../../../../../delivery/store/features/groups/slice';
export const setCurrentActivityFromSequence = createAsyncThunk(`${GroupsSlice}/layouts/deck/setCurrentActivityFromSequence`, (sequenceId, { dispatch, getState }) => __awaiter(void 0, void 0, void 0, function* () {
    const state = getState();
    const sequence = selectSequence(state);
    if (!sequence) {
        console.error('Sequence not found');
        throw new Error('Sequence not found');
    }
    const entry = findInSequence(sequence, sequenceId);
    if (!entry) {
        console.error('Entry not found');
        throw new Error('Entry not found');
    }
    /* console.log('setCurrentActivityFromSequence', { sequenceId, entry }); */
    return dispatch(setCurrentActivityId({ activityId: entry.resourceId }));
}));
//# sourceMappingURL=setCurrentActivityFromSequence.js.map