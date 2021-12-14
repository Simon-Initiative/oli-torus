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
import { writePartAttemptState } from 'data/persistence/state/intrinsic';
import { defaultGlobalEnv, evalScript, getAssignStatements, } from '../../../../../../adaptivity/scripting';
import { selectPreviewMode, selectSectionSlug } from '../../page/slice';
import { AttemptSlice, selectActivityAttemptState, selectById, upsertActivityAttemptState, } from '../slice';
export const savePartState = createAsyncThunk(`${AttemptSlice}/savePartState`, (payload, { dispatch, getState }) => __awaiter(void 0, void 0, void 0, function* () {
    const { attemptGuid, partAttemptGuid, response } = payload;
    const rootState = getState();
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    // update redux state to match optimistically
    const attemptRecord = selectById(rootState, attemptGuid);
    if (attemptRecord) {
        const partAttemptRecord = attemptRecord.parts.find((p) => p.attemptGuid === partAttemptGuid);
        if (partAttemptRecord) {
            const updated = Object.assign(Object.assign({}, attemptRecord), { parts: attemptRecord.parts.map((p) => {
                    const result = Object.assign({}, p);
                    if (p.attemptGuid === partAttemptRecord.attemptGuid) {
                        result.response = response;
                    }
                    return result;
                }) });
            yield dispatch(upsertActivityAttemptState({ attempt: updated }));
        }
    }
    // update scripting env with latest values
    const assignScripts = getAssignStatements(response);
    const scriptResult = [];
    if (Array.isArray(assignScripts)) {
        //Need to execute scripts one-by-one so that error free expression are evaluated and only the expression with error fails. It should not have any impacts
        assignScripts.forEach((variable) => {
            // update scripting env with latest values
            const { result } = evalScript(variable, defaultGlobalEnv);
            //Usually, the result is always null if expression is executes successfully. If there are any errors only then the result contains the error message
            if (result)
                scriptResult.push(result);
        });
    }
    /*  console.log('SAVE PART SCRIPT', { assignScript, scriptResult }); */
    // in preview mode we don't write to server, so we're done
    if (isPreviewMode) {
        // TODO: normalize response between client and server (nothing currently cares about it)
        return { result: scriptResult };
    }
    const finalize = false;
    return writePartAttemptState(sectionSlug, attemptGuid, partAttemptGuid, response, finalize);
}));
export const savePartStateToTree = createAsyncThunk(`${AttemptSlice}/savePartStateToTree`, (payload, { dispatch, getState }) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    const { attemptGuid, partAttemptGuid, response, activityTree } = payload;
    const rootState = getState();
    const attemptRecord = selectById(rootState, attemptGuid);
    const partId = (_a = attemptRecord === null || attemptRecord === void 0 ? void 0 : attemptRecord.parts.find((p) => p.attemptGuid === partAttemptGuid)) === null || _a === void 0 ? void 0 : _a.partId;
    if (!partId) {
        throw new Error('cannot find the partId to update');
    }
    const updates = activityTree.map((activity) => {
        var _a;
        const attempt = selectActivityAttemptState(rootState, activity.resourceId);
        if (!attempt) {
            return Promise.reject('could not find attempt!');
        }
        const attemptGuid = attempt.attemptGuid;
        const partAttemptGuid = (_a = attempt.parts.find((p) => p.partId === partId)) === null || _a === void 0 ? void 0 : _a.attemptGuid;
        if (!partAttemptGuid) {
            // means its in the tree, but doesn't own or inherit this part (some grandparent likely)
            return Promise.resolve('does not own part but thats OK');
        }
        /* console.log('updating activity tree part: ', {
          attemptGuid,
          partAttemptGuid,
          activity,
          response,
        }); */
        return dispatch(savePartState({ attemptGuid, partAttemptGuid, response }));
    });
    return Promise.all(updates);
}));
//# sourceMappingURL=savePart.js.map