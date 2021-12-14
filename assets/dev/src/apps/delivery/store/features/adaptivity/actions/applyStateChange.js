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
import { bulkApplyState, defaultGlobalEnv, getLocalizedStateSnapshot, } from '../../../../../../adaptivity/scripting';
import { selectCurrentActivityTree } from '../../groups/selectors/deck';
import { AdaptivitySlice, setMutationTriggered } from '../slice';
export const applyStateChange = createAsyncThunk(`${AdaptivitySlice}/applyStateChange`, (payload, { dispatch, getState }) => __awaiter(void 0, void 0, void 0, function* () {
    bulkApplyState(payload.operations, defaultGlobalEnv);
    // TODO: this should only be a DECK LAYOUT concern, think of a cleaner way
    const currentActivityTree = selectCurrentActivityTree(getState());
    const latestSnapshot = getLocalizedStateSnapshot((currentActivityTree || []).map((a) => a.id));
    // instead of sending the entire enapshot, taking latest values from store and sending that as mutate state in all the components
    const changes = payload.operations.reduce((collect, op) => {
        const localizedTarget = currentActivityTree === null || currentActivityTree === void 0 ? void 0 : currentActivityTree.reduce((target, activity) => {
            const localized = target.replace(`${activity.id}|`, '');
            return localized;
        }, op.target);
        collect[localizedTarget] = latestSnapshot[op.target];
        return collect;
    }, {});
    dispatch(setMutationTriggered({
        changes,
    }));
}));
//# sourceMappingURL=applyStateChange.js.map