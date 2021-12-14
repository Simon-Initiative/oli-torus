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
import { evalActivityAttempt, writePageAttemptState } from 'data/persistence/state/intrinsic';
import { check } from '../../../../../../adaptivity/rules-engine';
import { applyState, bulkApplyState, defaultGlobalEnv, getLocalizedStateSnapshot, getValue, } from '../../../../../../adaptivity/scripting';
import { createActivityAttempt } from '../../attempt/actions/createActivityAttempt';
import { selectExtrinsicState, updateExtrinsicState } from '../../attempt/slice';
import { selectCurrentActivityTree, selectCurrentActivityTreeAttemptState, } from '../../groups/selectors/deck';
import { selectPreviewMode, selectResourceAttemptGuid, selectSectionSlug } from '../../page/slice';
import { AdaptivitySlice, setLastCheckResults, setLastCheckTriggered } from '../slice';
const handleParentChildActivityVariableSync = (treeActivityIds, currentActivityId, localizedSnapshot) => {
    // handle parent/child variable sync  - Block Start
    const filteredTreeActivityIds = treeActivityIds.filter((activity) => activity !== currentActivityId);
    const parentVariables = filteredTreeActivityIds.map((item) => {
        //need to filter all the variable that belong to parents of the current activity
        const filteredParentScreenIdVariables = Object.keys(localizedSnapshot).filter((gotid) => {
            if (gotid.indexOf(item) !== -1 &&
                gotid.startsWith(item) &&
                !gotid.startsWith(currentActivityId)) {
                const variables = gotid.split('|');
                const v = gotid.replace(`${variables[0]}|stage`, `${currentActivityId}|stage`);
                //need to make sure that the variabled doesn't exist for the current activity as we don't want to update the values of current activity
                return Object.keys(localizedSnapshot).indexOf(v) === -1;
            }
        });
        return [...filteredParentScreenIdVariables];
    });
    const updatedCurrentActivityVariables = {};
    //now we are replacing the parent activity id with current activity Id
    parentVariables.forEach((key) => {
        key.forEach((item) => {
            const variables = item.split('|');
            const v = item.replace(`${variables[0]}|stage`, `${currentActivityId}|stage`);
            updatedCurrentActivityVariables[v] = localizedSnapshot[item];
        });
    });
    if (Object.keys(updatedCurrentActivityVariables).length) {
        //formatting the variables for sending it to scripting
        const finalCurrentActivityVariables = Object.keys(updatedCurrentActivityVariables).map((yup) => {
            const globalOp = {
                target: yup,
                operator: '=',
                value: updatedCurrentActivityVariables[yup],
            };
            return globalOp;
        });
        bulkApplyState(finalCurrentActivityVariables, defaultGlobalEnv);
    }
    // handle parent/child variable sync  - Block End
};
export const triggerCheck = createAsyncThunk(`${AdaptivitySlice}/triggerCheck`, (options, { dispatch, getState }) => __awaiter(void 0, void 0, void 0, function* () {
    var _a;
    const rootState = getState();
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    const resourceAttemptGuid = selectResourceAttemptGuid(rootState);
    const currentActivityTreeAttempts = selectCurrentActivityTreeAttemptState(rootState) || [];
    const currentAttempt = currentActivityTreeAttempts[(currentActivityTreeAttempts === null || currentActivityTreeAttempts === void 0 ? void 0 : currentActivityTreeAttempts.length) - 1];
    const currentActivityAttemptGuid = (currentAttempt === null || currentAttempt === void 0 ? void 0 : currentAttempt.attemptGuid) || '';
    const currentActivityTree = selectCurrentActivityTree(rootState);
    if (!currentActivityTree || !currentActivityTree.length) {
        throw new Error('No Activity Tree, something very wrong!');
    }
    const [currentActivity] = currentActivityTree.slice(-1);
    // update time on question
    applyState({
        target: 'session.timeOnQuestion',
        operator: '=',
        value: `${Date.now()} - {session.timeStartQuestion}`,
    }, defaultGlobalEnv);
    // for history tracking
    const trackingStampKey = `session.visitTimestamps.${currentActivity.id}`;
    const isActivityAlreadyVisited = !!getValue(trackingStampKey, defaultGlobalEnv);
    // don't update the time if student is revisiting that page
    if (!isActivityAlreadyVisited) {
        // looks like SS captures the date when we leave the page so we will capture the time here for tracking history
        // update the scripting
        const targetVisitTimeStampOp = {
            target: trackingStampKey,
            operator: '=',
            value: Date.now(),
        };
        applyState(targetVisitTimeStampOp, defaultGlobalEnv);
    }
    //update the store with the latest changes
    const currentTriggerStamp = Date.now();
    yield dispatch(setLastCheckTriggered({ timestamp: currentTriggerStamp }));
    const treeActivityIds = currentActivityTree.map((a) => a.id);
    const localizedSnapshot = getLocalizedStateSnapshot(treeActivityIds, defaultGlobalEnv);
    handleParentChildActivityVariableSync(treeActivityIds, currentActivity.id, localizedSnapshot);
    const extrinsicSnapshot = Object.keys(localizedSnapshot).reduce((acc, key) => {
        const isSessionVariable = key.startsWith('session.');
        const isVarVariable = key.startsWith('variables.');
        //Once Beagle App functionality is integrated, this can be removed
        const isBeagleVariable = key.startsWith('app.');
        if (isSessionVariable || isVarVariable || isBeagleVariable) {
            acc[key] = localizedSnapshot[key];
        }
        return acc;
    }, {});
    // update redux first because we need to get the latest full extrnisic state to write to the server
    yield dispatch(updateExtrinsicState({ state: extrinsicSnapshot }));
    if (!isPreviewMode) {
        // update the server with the latest changes
        const extrnisicState = selectExtrinsicState(getState());
        /* console.log('trigger check last min extrinsic state', {
          sectionSlug,
          resourceAttemptGuid,
          extrnisicState,
        }); */
        yield writePageAttemptState(sectionSlug, resourceAttemptGuid, extrnisicState);
    }
    let checkResult;
    let isCorrect = false;
    let score = 0;
    let outOf = 0;
    const scoringContext = {
        currentAttemptNumber: (currentAttempt === null || currentAttempt === void 0 ? void 0 : currentAttempt.attemptNumber) || 1,
        maxAttempt: currentActivity.content.custom.maxAttempt || 0,
        maxScore: currentActivity.content.custom.maxScore || 0,
        trapStateScoreScheme: currentActivity.content.custom.trapStateScoreScheme || false,
        negativeScoreAllowed: currentActivity.content.custom.negativeScoreAllowed || false,
    };
    // if preview mode, gather up all state and rules from redux
    if (isPreviewMode) {
        // need to get this fresh right now so it is the latest
        const rootState = getState();
        const currentActivityTreeAttempts = selectCurrentActivityTreeAttemptState(rootState) || [];
        const [currentAttempt] = currentActivityTreeAttempts.slice(-1);
        const treeActivityIds = currentActivityTree.map((a) => a.id).reverse();
        const localizedSnapshot = getLocalizedStateSnapshot(treeActivityIds, defaultGlobalEnv);
        const currentRules = JSON.parse(JSON.stringify(((_a = currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.authoring) === null || _a === void 0 ? void 0 : _a.rules) || []));
        // custom rules can be provided via PreviewTools Adaptivity pane for specific rule triggering
        const customRules = options.customRules || [];
        const rulesToCheck = customRules.length > 0 ? customRules : currentRules;
        console.log('PRE CHECK RESULT', { currentActivity, currentRules, localizedSnapshot });
        const check_call_result = (yield check(localizedSnapshot, rulesToCheck, scoringContext));
        checkResult = check_call_result.results;
        isCorrect = check_call_result.correct;
        score = check_call_result.score;
        outOf = check_call_result.out_of;
        console.log('CHECK RESULT', {
            check_call_result,
            currentActivity,
            currentRules,
            checkResult,
            localizedSnapshot,
            currentActivityTreeAttempts,
            currentAttempt,
            currentActivityTree,
        });
    }
    else {
        // need to get this fresh right now so it is the latest
        const rootState = getState();
        const currentActivityTreeAttempts = selectCurrentActivityTreeAttemptState(rootState) || [];
        const [currentAttempt] = currentActivityTreeAttempts.slice(-1);
        if (!currentActivityAttemptGuid) {
            console.error('not current attempt, cannot eval', { currentActivityAttemptGuid });
            return;
        }
        // we have to send all the current activity attempt state to the server
        // because the server doesn't know the current sequence id and will strip out
        // all sequence ids from the path for these only
        const treeActivityIds = currentActivityTree.map((a) => a.id).reverse();
        const localizedSnapshot = getLocalizedStateSnapshot(treeActivityIds, defaultGlobalEnv);
        // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
        const partResponses = currentAttempt.parts.map(({ partId, attemptGuid, response }) => {
            // snapshot is more up to date
            // TODO: resolve syncing issue, this is a workaround
            let finalResponse = response;
            if (!finalResponse) {
                // if a null response, it actually might live on a parent attempt
                // walk backwards to find the parent
                finalResponse = currentActivityTreeAttempts.reduce((acc, attempt) => {
                    const part = attempt === null || attempt === void 0 ? void 0 : attempt.parts.find((p) => p.partId === partId);
                    return (part === null || part === void 0 ? void 0 : part.response) || acc;
                }, null);
            }
            if (finalResponse) {
                finalResponse = Object.keys(finalResponse).reduce((acc, key) => {
                    acc[key] = Object.assign({}, finalResponse[key]);
                    const item = acc[key];
                    if (item.path) {
                        const snapshotValue = localizedSnapshot[item.path];
                        if (snapshotValue !== undefined) {
                            item.value = snapshotValue;
                        }
                    }
                    return acc;
                }, {});
            }
            return {
                attemptGuid,
                response: { input: finalResponse },
            };
        });
        /* console.log('CHECKING', {
          sectionSlug,
          currentActivityTreeAttempts,
          currentAttempt,
          currentActivityTree,
          localizedSnapshot,
          partResponses,
        }); */
        const evalResult = yield evalActivityAttempt(sectionSlug, currentActivityAttemptGuid, partResponses);
        /* console.log('EVAL RESULT', { evalResult }); */
        const resultData = evalResult.result.actions;
        checkResult = resultData.results;
        isCorrect = resultData.correct;
        score = resultData.score;
        outOf = resultData.out_of;
    }
    let attempt = currentAttempt;
    if (!isCorrect) {
        /* console.log('Incorrect, time for new attempt'); */
        const { payload: newAttempt } = yield dispatch(createActivityAttempt({ sectionSlug, attemptGuid: currentActivityAttemptGuid }));
        attempt = newAttempt;
        const updateAttempt = [
            {
                target: 'session.attemptNumber',
                operator: '=',
                value: attempt.attemptNumber,
            },
            {
                target: `${currentActivity.id}|session.attemptNumber`,
                operator: '=',
                value: attempt.attemptNumber,
            },
        ];
        bulkApplyState(updateAttempt, defaultGlobalEnv);
        // need to write attempt number to extrinsic state?
        // TODO: also get attemptNumber alwasy from the attempt and update scripting instead
    }
    // TODO: get score back from check result
    bulkApplyState([
        { target: 'session.currentQuestionScore', operator: '=', value: score },
        { target: `session.visits.${currentActivity.id}`, operator: '=', value: 1 },
    ], defaultGlobalEnv);
    yield dispatch(setLastCheckResults({
        timestamp: currentTriggerStamp,
        results: checkResult,
        attempt,
        correct: isCorrect,
        score,
        outOf,
    }));
}));
//# sourceMappingURL=triggerCheck.js.map