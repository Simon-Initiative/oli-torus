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
import { handleValueExpression } from 'apps/delivery/layouts/deck/DeckLayoutFooter';
import { getBulkActivitiesForAuthoring } from 'data/persistence/activity';
import { getBulkAttemptState, getPageAttemptState, writePageAttemptState, } from 'data/persistence/state/intrinsic';
import guid from 'utils/guid';
import { bulkApplyState, defaultGlobalEnv, evalScript, getAssignScript, getEnvState, } from '../../../../../../adaptivity/scripting';
import { selectCurrentActivity, selectCurrentActivityId, setActivities, setCurrentActivityId, } from '../../activities/slice';
import { setInitStateFacts, setLessonEnd } from '../../adaptivity/slice';
import { loadActivityAttemptState, updateExtrinsicState } from '../../attempt/slice';
import { selectActivityTypes, selectEnableHistory, selectNavigationSequence, selectPreviewMode, selectResourceAttemptGuid, selectSectionSlug, setScore, } from '../../page/slice';
import { selectCurrentActivityTree, selectSequence } from '../selectors/deck';
import { GroupsSlice } from '../slice';
import { getNextQBEntry, getParentBank } from './navUtils';
export const initializeActivity = createAsyncThunk(`${GroupsSlice}/deck/initializeActivity`, (activityId, thunkApi) => __awaiter(void 0, void 0, void 0, function* () {
    var _a, _b, _c;
    const rootState = thunkApi.getState();
    const isPreviewMode = selectPreviewMode(rootState);
    const enableHistory = selectEnableHistory(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    const resourceAttemptGuid = selectResourceAttemptGuid(rootState);
    const sequence = selectSequence(rootState);
    const currentSequenceId = (_a = sequence.find((entry) => entry.activity_id === activityId)) === null || _a === void 0 ? void 0 : _a.custom.sequenceId;
    if (!currentSequenceId) {
        throw new Error(`Activity ${activityId} not found in sequence!`);
    }
    const currentActivity = selectCurrentActivity(rootState);
    const currentActivityTree = selectCurrentActivityTree(rootState);
    const resumeTarget = {
        target: `session.resume`,
        operator: '=',
        value: currentSequenceId,
    };
    const timeOnQuestion = {
        target: 'session.timeOnQuestion',
        operator: '=',
        value: 0,
    };
    const timeStartOp = {
        target: 'session.timeStartQuestion',
        operator: '=',
        value: Date.now(),
    };
    const timeExceededOp = {
        target: 'session.questionTimeExceeded',
        operator: '=',
        value: false,
    };
    const currentAttemptNumber = 1;
    const attemptNumberOp = {
        target: 'session.attemptNumber',
        operator: '=',
        value: currentAttemptNumber,
    };
    const targettedAttemptNumberOp = {
        target: `${currentSequenceId}|session.attemptNumber`,
        operator: '=',
        value: currentAttemptNumber,
    };
    const tutorialScoreOp = {
        target: 'session.tutorialScore',
        operator: '+',
        value: '{session.currentQuestionScore}',
    };
    const currentScoreOp = {
        target: 'session.currentQuestionScore',
        operator: '=',
        value: 0,
    };
    const sessionOps = [
        resumeTarget,
        timeStartOp,
        timeOnQuestion,
        timeExceededOp,
        attemptNumberOp,
        targettedAttemptNumberOp,
        tutorialScoreOp,
        // must come *after* the tutorial score op
        currentScoreOp,
    ];
    const globalSnapshot = getEnvState(defaultGlobalEnv);
    const trackingStampKey = `session.visitTimestamps.${currentSequenceId}`;
    const isActivityAlreadyVisited = globalSnapshot[trackingStampKey];
    // don't update the time if student is revisiting that page
    if (!isActivityAlreadyVisited) {
        // looks like SS captures the date when we leave the page but it should
        // show in the history as soon as we visit but it does not show the timestamp
        // so we will capture the time on trigger check
        const targetVisitTimeStampOp = {
            target: trackingStampKey,
            operator: '=',
            value: 0,
        };
        sessionOps.push(targetVisitTimeStampOp);
    }
    // init state is always "local" but the parts may come from parent layers
    // in that case they actually need to be written to the parent layer values
    const initState = ((_c = (_b = currentActivity === null || currentActivity === void 0 ? void 0 : currentActivity.content) === null || _b === void 0 ? void 0 : _b.custom) === null || _c === void 0 ? void 0 : _c.facts) || [];
    const arrInitFacts = [];
    const globalizedInitState = initState.map((s) => {
        arrInitFacts.push(`${s.target}`);
        if (s.target.indexOf('stage.') !== 0) {
            return Object.assign({}, s);
        }
        const [, targetPart] = s.target.split('.');
        const ownerActivity = currentActivityTree === null || currentActivityTree === void 0 ? void 0 : currentActivityTree.find((activity) => !!activity.content.partsLayout.find((p) => p.id === targetPart));
        const modifiedValue = handleValueExpression(currentActivityTree, s.value, s.operator);
        if (!ownerActivity) {
            // shouldn't happen, but ignore I guess
            return Object.assign(Object.assign({}, s), { value: modifiedValue });
        }
        return Object.assign(Object.assign({}, s), { target: `${ownerActivity.id}|${s.target}`, value: modifiedValue });
    });
    thunkApi.dispatch(setInitStateFacts({ facts: arrInitFacts }));
    const results = bulkApplyState([...sessionOps, ...globalizedInitState], defaultGlobalEnv);
    const applyStateHasErrors = results.some((r) => r.result !== null);
    if (applyStateHasErrors) {
        console.warn('[INIT STATE] applyState has errors', results);
    }
    // now that the scripting env should be up to date, need to update attempt state in redux and server
    const currentState = getEnvState(defaultGlobalEnv);
    const sessionState = Object.keys(currentState).reduce((collect, key) => {
        if (key.indexOf('session.') === 0) {
            collect[key] = currentState[key];
        }
        return collect;
    }, {});
    /* console.log('about to update score [deck]', {
      currentState,
      score: sessionState['session.tutorialScore'],
    }); */
    const tutScore = sessionState['session.tutorialScore'] || 0;
    const curScore = sessionState['session.currentQuestionScore'] || 0;
    thunkApi.dispatch(setScore({ score: tutScore + curScore }));
    // optimistically write to redux
    thunkApi.dispatch(updateExtrinsicState({ state: sessionState }));
    // in preview mode we don't talk to the server, so we're done
    if (isPreviewMode) {
        const allGood = results.every(({ result }) => result === null);
        // TODO: report actual errors?
        const status = allGood ? 'success' : 'error';
        return { result: status };
    }
    yield writePageAttemptState(sectionSlug, resourceAttemptGuid, sessionState);
}));
const getSessionVisitHistory = (sectionSlug, resourceAttemptGuid, isPreviewMode = false) => __awaiter(void 0, void 0, void 0, function* () {
    let pageAttemptState;
    if (isPreviewMode) {
        const allState = getEnvState(defaultGlobalEnv);
        pageAttemptState = allState;
    }
    else {
        const { result } = yield getPageAttemptState(sectionSlug, resourceAttemptGuid);
        pageAttemptState = result;
    }
    return Object.keys(pageAttemptState)
        .filter((key) => key.indexOf('session.visits.') === 0)
        .map((visitKey) => ({
        sequenceId: visitKey.replace('session.visits.', ''),
        visitCount: pageAttemptState[visitKey],
    }));
});
export const navigateToNextActivity = createAsyncThunk(`${GroupsSlice}/deck/navigateToNextActivity`, (_, thunkApi) => __awaiter(void 0, void 0, void 0, function* () {
    var _d, _e, _f, _g;
    const rootState = thunkApi.getState();
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    const resourceAttemptGuid = selectResourceAttemptGuid(rootState);
    const sequence = selectSequence(rootState);
    const currentActivityId = selectCurrentActivityId(rootState);
    const currentIndex = sequence.findIndex((entry) => entry.custom.sequenceId === currentActivityId);
    let nextSequenceEntry = null;
    let navError = '';
    if (currentIndex >= 0) {
        const nextIndex = currentIndex + 1;
        nextSequenceEntry = sequence[nextIndex];
        const parentBank = getParentBank(sequence, currentIndex);
        const visitHistory = yield getSessionVisitHistory(sectionSlug, resourceAttemptGuid, isPreviewMode);
        if (parentBank) {
            nextSequenceEntry = getNextQBEntry(sequence, parentBank, visitHistory);
        }
        while (((_d = nextSequenceEntry === null || nextSequenceEntry === void 0 ? void 0 : nextSequenceEntry.custom) === null || _d === void 0 ? void 0 : _d.isBank) || ((_e = nextSequenceEntry === null || nextSequenceEntry === void 0 ? void 0 : nextSequenceEntry.custom) === null || _e === void 0 ? void 0 : _e.isLayer)) {
            while (nextSequenceEntry && ((_f = nextSequenceEntry === null || nextSequenceEntry === void 0 ? void 0 : nextSequenceEntry.custom) === null || _f === void 0 ? void 0 : _f.isBank)) {
                // this runs when we're about to enter a QB for the first time
                nextSequenceEntry = getNextQBEntry(sequence, nextSequenceEntry, visitHistory);
            }
            while (nextSequenceEntry && ((_g = nextSequenceEntry === null || nextSequenceEntry === void 0 ? void 0 : nextSequenceEntry.custom) === null || _g === void 0 ? void 0 : _g.isLayer)) {
                // for layers if you try to navigate it should go to first child
                const firstChild = sequence.find((entry) => {
                    var _a;
                    return ((_a = entry.custom) === null || _a === void 0 ? void 0 : _a.layerRef) ===
                        nextSequenceEntry.custom.sequenceId;
                });
                if (!firstChild) {
                    navError = 'Target Layer has no children!';
                }
                nextSequenceEntry = firstChild;
            }
        }
        if (!nextSequenceEntry) {
            // If is end of sequence, return and set isEnd to truthy
            thunkApi.dispatch(setLessonEnd({ lessonEnded: true }));
            return;
        }
    }
    else {
        navError = `Current Activity ${currentActivityId} not found in sequence`;
    }
    if (navError) {
        throw new Error(navError);
    }
    thunkApi.dispatch(setCurrentActivityId({ activityId: nextSequenceEntry === null || nextSequenceEntry === void 0 ? void 0 : nextSequenceEntry.custom.sequenceId }));
}));
export const navigateToPrevActivity = createAsyncThunk(`${GroupsSlice}/deck/navigateToPrevActivity`, (_, thunkApi) => __awaiter(void 0, void 0, void 0, function* () {
    var _h;
    const rootState = thunkApi.getState();
    const sequence = selectSequence(rootState);
    const currentActivityId = selectCurrentActivityId(rootState);
    const currentIndex = sequence.findIndex((entry) => entry.custom.sequenceId === currentActivityId);
    let previousEntry = null;
    let navError = '';
    if (currentIndex >= 0) {
        const nextIndex = currentIndex - 1;
        previousEntry = sequence[nextIndex];
        while (previousEntry && ((_h = previousEntry === null || previousEntry === void 0 ? void 0 : previousEntry.custom) === null || _h === void 0 ? void 0 : _h.isLayer)) {
            const layerIndex = sequence.findIndex((entry) => { var _a; return entry.custom.sequenceId === ((_a = previousEntry === null || previousEntry === void 0 ? void 0 : previousEntry.custom) === null || _a === void 0 ? void 0 : _a.sequenceId); });
            /* console.log({ currentIndex, layerIndex }); */
            previousEntry = sequence[layerIndex - 1];
        }
    }
    else {
        navError = `Current Activity ${currentActivityId} not found in sequence`;
    }
    if (navError) {
        throw new Error(navError);
    }
    thunkApi.dispatch(setCurrentActivityId({ activityId: previousEntry === null || previousEntry === void 0 ? void 0 : previousEntry.custom.sequenceId }));
}));
export const navigateToFirstActivity = createAsyncThunk(`${GroupsSlice}/deck/navigateToFirstActivity`, (_, thunkApi) => __awaiter(void 0, void 0, void 0, function* () {
    const rootState = thunkApi.getState();
    const sequence = selectSequence(rootState);
    const navigationSequences = selectNavigationSequence(sequence);
    if (!(navigationSequences === null || navigationSequences === void 0 ? void 0 : navigationSequences.length)) {
        console.warn(`Invalid sequence!`);
        return;
    }
    const nextActivityId = navigationSequences[0].custom.sequenceId;
    thunkApi.dispatch(setCurrentActivityId({ activityId: nextActivityId }));
}));
export const navigateToLastActivity = createAsyncThunk(`${GroupsSlice}/deck/navigateToLastActivity`, (_, thunkApi) => __awaiter(void 0, void 0, void 0, function* () {
    const rootState = thunkApi.getState();
    const sequence = selectSequence(rootState);
    const nextActivityId = 1;
    thunkApi.dispatch(setCurrentActivityId({ activityId: nextActivityId }));
}));
export const navigateToActivity = createAsyncThunk(`${GroupsSlice}/deck/navigateToActivity`, (sequenceId, thunkApi) => __awaiter(void 0, void 0, void 0, function* () {
    var _j, _k, _l, _m;
    const rootState = thunkApi.getState();
    const isPreviewMode = selectPreviewMode(rootState);
    const sectionSlug = selectSectionSlug(rootState);
    const resourceAttemptGuid = selectResourceAttemptGuid(rootState);
    const sequence = selectSequence(rootState);
    const desiredIndex = sequence.findIndex((s) => { var _a; return ((_a = s.custom) === null || _a === void 0 ? void 0 : _a.sequenceId) === sequenceId; });
    let nextSequenceEntry = null;
    let navError = '';
    const visitHistory = yield getSessionVisitHistory(sectionSlug, resourceAttemptGuid, isPreviewMode);
    if (desiredIndex >= 0) {
        nextSequenceEntry = sequence[desiredIndex];
        while (((_j = nextSequenceEntry === null || nextSequenceEntry === void 0 ? void 0 : nextSequenceEntry.custom) === null || _j === void 0 ? void 0 : _j.isBank) || ((_k = nextSequenceEntry === null || nextSequenceEntry === void 0 ? void 0 : nextSequenceEntry.custom) === null || _k === void 0 ? void 0 : _k.isLayer)) {
            while (nextSequenceEntry && ((_l = nextSequenceEntry === null || nextSequenceEntry === void 0 ? void 0 : nextSequenceEntry.custom) === null || _l === void 0 ? void 0 : _l.isBank)) {
                // this runs when we're about to enter a QB for the first time
                nextSequenceEntry = getNextQBEntry(sequence, nextSequenceEntry, visitHistory);
            }
            while (nextSequenceEntry && ((_m = nextSequenceEntry === null || nextSequenceEntry === void 0 ? void 0 : nextSequenceEntry.custom) === null || _m === void 0 ? void 0 : _m.isLayer)) {
                // for layers if you try to navigate it should go to first child
                const firstChild = sequence.find((entry) => {
                    var _a;
                    return ((_a = entry.custom) === null || _a === void 0 ? void 0 : _a.layerRef) ===
                        nextSequenceEntry.custom.sequenceId;
                });
                if (!firstChild) {
                    navError = 'Target Layer has no children!';
                }
                nextSequenceEntry = firstChild;
            }
        }
        if (!nextSequenceEntry) {
            // If is end of sequence, return and set isEnd to truthy
            thunkApi.dispatch(setLessonEnd({ lessonEnded: true }));
            return;
        }
    }
    else {
        navError = `Current Activity ${sequenceId} not found in sequence`;
    }
    if (navError) {
        throw new Error(navError);
    }
    thunkApi.dispatch(setCurrentActivityId({ activityId: nextSequenceEntry === null || nextSequenceEntry === void 0 ? void 0 : nextSequenceEntry.custom.sequenceId }));
}));
export const loadActivities = createAsyncThunk(`${GroupsSlice}/deck/loadActivities`, (activityAttemptMapping, thunkApi) => __awaiter(void 0, void 0, void 0, function* () {
    const rootState = thunkApi.getState();
    const sectionSlug = selectSectionSlug(rootState);
    const isPreviewMode = selectPreviewMode(rootState);
    let results;
    if (isPreviewMode) {
        const activityIds = activityAttemptMapping.map((m) => m.id);
        results = yield getBulkActivitiesForAuthoring(sectionSlug, activityIds);
    }
    else {
        const attemptGuids = activityAttemptMapping.map((m) => m.attemptGuid);
        results = yield getBulkAttemptState(sectionSlug, attemptGuids);
    }
    const sequence = selectSequence(rootState);
    const activityTypes = selectActivityTypes(rootState);
    const activities = results.map((result) => {
        const resultActivityId = isPreviewMode ? result.id : result.activityId;
        const sequenceEntry = sequence.find((entry) => entry.activity_id === resultActivityId);
        if (!sequenceEntry) {
            console.warn(`Activity ${result.id} not found in the page model!`);
            return;
        }
        const attemptEntry = activityAttemptMapping.find((m) => m.id === sequenceEntry.activity_id);
        const activityType = activityTypes.find((t) => t.id === result.activityType);
        let partAttempts = result.partAttempts;
        if (isPreviewMode) {
            partAttempts = result.authoring.parts.map((p) => {
                return {
                    attemptGuid: `preview_${guid()}`,
                    attemptNumber: 1,
                    dateEvaluated: null,
                    feedback: null,
                    outOf: null,
                    partId: p.id,
                    response: null,
                    score: null,
                };
            });
        }
        const activityModel = {
            id: sequenceEntry.custom.sequenceId,
            resourceId: sequenceEntry.activity_id,
            content: isPreviewMode ? result.content : result.model,
            authoring: result.authoring || null,
            activityType,
            title: result.title,
            attemptGuid: (attemptEntry === null || attemptEntry === void 0 ? void 0 : attemptEntry.attemptGuid) || '',
        };
        const attemptState = {
            attemptGuid: (attemptEntry === null || attemptEntry === void 0 ? void 0 : attemptEntry.attemptGuid) || '',
            activityId: activityModel.resourceId,
            attemptNumber: result.attemptNumber || 1,
            dateEvaluated: result.dateEvaluated || null,
            score: result.score || null,
            outOf: result.outOf || null,
            parts: partAttempts,
            hasMoreAttempts: result.hasMoreAttempts || true,
            hasMoreHints: result.hasMoreHints || true,
        };
        return { model: activityModel, state: attemptState };
    });
    const models = activities.map((a) => a === null || a === void 0 ? void 0 : a.model);
    const states = activities
        .map((a) => a === null || a === void 0 ? void 0 : a.state)
        .filter((s) => s !== undefined);
    thunkApi.dispatch(loadActivityAttemptState({ attempts: states }));
    thunkApi.dispatch(setActivities({ activities: models }));
    // update the scripting environment with the latest activity state
    states.forEach((state) => {
        const hasResponse = state.parts.some((p) => p.response);
        /* console.log({ state, hasResponse }); */
        if (hasResponse) {
            // update globalEnv with the latest activity state
            const updateValues = state.parts.reduce((acc, p) => {
                if (!p.response) {
                    return acc;
                }
                const inputs = Object.keys(p.response).reduce((acc2, key) => {
                    acc2[p.response[key].path] = p.response[key].value;
                    return acc2;
                }, {});
                return Object.assign(Object.assign({}, acc), inputs);
            }, {});
            const assignScript = getAssignScript(updateValues, defaultGlobalEnv);
            const { result: scriptResult } = evalScript(assignScript, defaultGlobalEnv);
            if (scriptResult !== null) {
                console.warn('Error in state restore script', { state, scriptResult });
            }
            /* console.log('STATE RESTORE', { scriptResult }); */
        }
    });
    return { attempts: states, activities: models };
}));
//# sourceMappingURL=deck.js.map