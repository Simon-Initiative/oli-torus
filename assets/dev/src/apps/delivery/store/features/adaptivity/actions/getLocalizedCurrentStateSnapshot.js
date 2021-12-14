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
import { getLocalizedStateSnapshot } from 'adaptivity/scripting';
import { selectCurrentActivityTree } from '../../groups/selectors/deck';
import { AdaptivitySlice } from '../slice';
export const getLocalizedCurrentStateSnapshot = createAsyncThunk(`${AdaptivitySlice}/getLocalizedCurrentStateSnapshot`, (payload, thunkAPI) => __awaiter(void 0, void 0, void 0, function* () {
    const currentActivityTree = selectCurrentActivityTree(thunkAPI.getState());
    if (!currentActivityTree) {
        return { snapshot: {} };
    }
    const currentActivityIds = currentActivityTree.map((a) => a.id);
    const snapshot = getLocalizedStateSnapshot(currentActivityIds);
    return { snapshot };
}));
//# sourceMappingURL=getLocalizedCurrentStateSnapshot.js.map