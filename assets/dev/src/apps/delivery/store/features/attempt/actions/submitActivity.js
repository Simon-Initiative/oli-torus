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
import { writeActivityAttemptState } from 'data/persistence/state/intrinsic';
import { defaultGlobalEnv, evalScript, getAssignScript, } from '../../../../../../adaptivity/scripting';
import { selectPreviewMode, selectSectionSlug } from '../../page/slice';
import { AttemptSlice, selectById, upsertActivityAttemptState } from '../slice';
export const submitActivityState = createAsyncThunk(`${AttemptSlice}/submitActivityState`, (payload, { dispatch, getState }) => __awaiter(void 0, void 0, void 0, function* () {
    const { attemptGuid, partResponses } = payload;
    const rootState = getState();
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    // update redux state to match optimistically
    const attemptRecord = selectById(rootState, attemptGuid);
    if (attemptRecord) {
        const updated = Object.assign(Object.assign({}, attemptRecord), { parts: partResponses });
        yield dispatch(upsertActivityAttemptState({ attempt: updated }));
    }
    // update script env with latest values
    const assignScript = getAssignScript(partResponses, defaultGlobalEnv);
    const { result: scriptResult } = evalScript(assignScript, defaultGlobalEnv);
    // in preview mode we don't talk to the server, so we're done
    if (isPreviewMode) {
        // TODO: normalize result response between client and server (currently nothing cares)
        return { result: scriptResult };
    }
    const finalize = true;
    return writeActivityAttemptState(sectionSlug, attemptGuid, partResponses, finalize);
}));
//# sourceMappingURL=submitActivity.js.map