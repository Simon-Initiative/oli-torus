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
import { createNewActivityAttempt } from 'data/persistence/state/intrinsic';
import guid from 'utils/guid';
import { selectPreviewMode } from '../../page/slice';
import { AttemptSlice, selectById, upsertActivityAttemptState } from '../slice';
export const createActivityAttempt = createAsyncThunk(`${AttemptSlice}/createActivityAttempt`, (payload, { dispatch, getState }) => __awaiter(void 0, void 0, void 0, function* () {
    const { sectionSlug, attemptGuid } = payload;
    const rootState = getState();
    const isPreviewMode = selectPreviewMode(rootState);
    let attempt = selectById(rootState, attemptGuid);
    if (!attempt) {
        throw new Error(`Unable to find attempt with guid: ${attemptGuid}`);
    }
    const resourceId = attempt.activityId;
    if (isPreviewMode) {
        // make mutable
        attempt = JSON.parse(JSON.stringify(attempt));
        attempt.attemptNumber += 1;
        attempt.attemptGuid = `npreview_${guid()}`;
    }
    else {
        const seedResponses = true; // parameterize at function level?
        const new_attempt_result = yield createNewActivityAttempt(sectionSlug, attemptGuid, seedResponses);
        /* console.log({ new_attempt_result }); */
        attempt = new_attempt_result.attemptState;
        // this should be for the same resource id, which doesn't come back from the server
        // because it's already based on the previous attemptGuid
        attempt.activityId = resourceId;
    }
    yield dispatch(upsertActivityAttemptState({ attempt }));
    return attempt;
}));
//# sourceMappingURL=createActivityAttempt.js.map