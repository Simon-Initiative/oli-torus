var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
/* eslint-disable react/prop-types */
import { defaultGlobalEnv, getValue } from 'adaptivity/scripting';
import { makeFeedback, } from 'components/activities/types';
import { Environment } from 'janus-script';
import React, { useEffect, useRef, useState } from 'react';
import { useSelector } from 'react-redux';
import { clone } from 'utils/common';
import { contexts } from '../../../types/applicationContext';
import { selectCurrentActivityId } from '../store/features/activities/slice';
import { selectHistoryNavigationActivity, selectInitPhaseComplete, selectInitStateFacts, selectLastCheckResults, selectLastCheckTriggered, selectLastMutateChanges, selectLastMutateTriggered, } from '../store/features/adaptivity/slice';
import { debounce } from 'lodash';
import * as Extrinsic from 'data/persistence/extrinsic';
import { selectPreviewMode, selectUserId } from '../store/features/page/slice';
import { NotificationType } from './NotificationContext';
import { selectCurrentActivityTree } from '../store/features/groups/selectors/deck';
import { templatizeText } from './TextParser';
const defaultHandler = () => __awaiter(void 0, void 0, void 0, function* () {
    /* console.log('DEFAULT HANDLER AR'); */
    return true;
});
// because of events and function references, we need to store state outside of the function
const sharedAttemptStateMap = new Map();
const AllAttemptStateList = [];
// the activity renderer should be capable of handling *any* activity type, not just adaptive
// most events should be simply bubbled up to the layout renderer for handling
const ActivityRenderer = ({ activity, attempt, onActivitySave = defaultHandler, onActivitySubmit = defaultHandler, onActivityReset = defaultHandler, onActivitySavePart = defaultHandler, onActivitySubmitPart = defaultHandler, onActivityRequestHint = defaultHandler, onActivityResetPart = defaultHandler, onActivitySubmitEvaluations = defaultHandler, onActivityReady = defaultHandler, onRequestLatestState = () => __awaiter(void 0, void 0, void 0, function* () { return ({ snapshot: {} }); }), adaptivityDomain = 'stage', }) => {
    var _a;
    const isPreviewMode = useSelector(selectPreviewMode);
    const currentUserId = useSelector(selectUserId);
    const saveUserData = (attemptGuid, partAttemptGuid, payload) => __awaiter(void 0, void 0, void 0, function* () {
        const objId = `${payload.key}`;
        yield debouncedSaveData({ isPreviewMode, payload, objId, value: payload.value });
    });
    const readUserData = (attemptGuid, partAttemptGuid, payload) => __awaiter(void 0, void 0, void 0, function* () {
        // Read only the key from the simid
        const objId = `${payload.key}`;
        const data = yield debouncedReadData({ isPreviewMode, payload, objId });
        return data;
    });
    const debouncedReadData = debounce(({ isPreviewMode, payload, objId }) => __awaiter(void 0, void 0, void 0, function* () {
        var _b;
        const retrievedData = yield Extrinsic.readGlobalUserState([payload.simId], isPreviewMode);
        return (_b = retrievedData === null || retrievedData === void 0 ? void 0 : retrievedData[payload.simId]) === null || _b === void 0 ? void 0 : _b[objId];
    }), 500, { maxWait: 10000, leading: true, trailing: false });
    const debouncedSaveData = debounce(({ isPreviewMode, payload, objId, value }) => __awaiter(void 0, void 0, void 0, function* () {
        yield Extrinsic.updateGlobalUserState({ [payload.simId]: { [objId]: value } }, isPreviewMode);
    }), 200, { maxWait: 10000, leading: true, trailing: false });
    const activityState = {
        attemptGuid: 'foo',
        attemptNumber: 1,
        dateEvaluated: null,
        score: null,
        outOf: null,
        parts: [],
        hasMoreAttempts: true,
        hasMoreHints: true,
    };
    const partState = {
        attemptGuid: 'TODO1234',
        attemptNumber: 1,
        dateEvaluated: null,
        score: null,
        outOf: null,
        response: '',
        feedback: makeFeedback(''),
        hints: [],
        partId: 1,
        hasMoreAttempts: false,
        hasMoreHints: false,
    };
    const onSaveActivity = (attemptGuid, partResponses) => __awaiter(void 0, void 0, void 0, function* () {
        yield onActivitySave(activity.id, attemptGuid, partResponses);
        // TODO: use something from parent call to determine if is actually a success
        const result = {
            type: 'success',
        };
        return result;
    });
    const onSubmitActivity = (attemptGuid, partResponses) => __awaiter(void 0, void 0, void 0, function* () {
        yield onActivitySubmit(activity.id, attemptGuid, partResponses);
        // TODO: use something from parent call to determine if is actually a success
        const result = {
            type: 'success',
            actions: [],
        };
        return result;
    });
    const onResetActivity = (attemptGuid) => __awaiter(void 0, void 0, void 0, function* () {
        yield onActivityReset(activity.id, attemptGuid);
        // TODO
        const result = {
            type: 'success',
            attemptState: activityState,
            model: activity,
        };
        return result;
    });
    const onRequestHint = (attemptGuid, partAttemptGuid) => __awaiter(void 0, void 0, void 0, function* () {
        yield onActivityRequestHint(activity.id, attemptGuid, partAttemptGuid);
        const result = {
            type: 'success',
            hasMoreHints: false,
        };
        return result;
    });
    const onSavePart = (attemptGuid, partAttemptGuid, response) => __awaiter(void 0, void 0, void 0, function* () {
        /* console.log('onSavePart (ActivityRenderer)', { attemptGuid, partAttemptGuid, response }); */
        const result = yield onActivitySavePart(activity.id, attemptGuid, partAttemptGuid, response);
        return result;
    });
    const onSubmitPart = (attemptGuid, partAttemptGuid, response) => __awaiter(void 0, void 0, void 0, function* () {
        yield onActivitySubmitPart(activity.id, attemptGuid, partAttemptGuid, response);
        const result = {
            type: 'success',
            actions: [],
        };
        return result;
    });
    const onResetPart = (attemptGuid, partAttemptGuid) => __awaiter(void 0, void 0, void 0, function* () {
        yield onActivityResetPart(activity.id, attemptGuid, partAttemptGuid);
        const result = {
            type: 'success',
            attemptState: partState,
        };
        return result;
    });
    const onSubmitEvaluations = (attemptGuid, clientEvaluations) => __awaiter(void 0, void 0, void 0, function* () {
        yield onActivitySubmitEvaluations(activity.id, attemptGuid, clientEvaluations);
        const result = {
            type: 'success',
            actions: [],
        };
        return result;
    });
    const onReady = (attemptGuid) => __awaiter(void 0, void 0, void 0, function* () {
        const results = yield onActivityReady(activity.id, attemptGuid);
        const result = {
            type: 'success',
        };
        // provide each activity with a local scope based on the global scope
        // should allow it to do some same screen interactivity/adaptivity
        const activityScriptEnv = new Environment(defaultGlobalEnv);
        /* evalScript(`let global.screenId = "${activity.id}"`, activityScriptEnv); */
        // BS: TODO make compatible with *any* activity
        return Object.assign(Object.assign(Object.assign({}, results), result), { env: activityScriptEnv, domain: adaptivityDomain });
    });
    const onResize = (attemptGuid) => __awaiter(void 0, void 0, void 0, function* () {
        // no need to do anything for now.
        /*  console.log('onResize called'); */
    });
    const bridgeEvents = {
        saveActivity: onSaveActivity,
        submitActivity: onSubmitActivity,
        resetActivity: onResetActivity,
        savePart: onSavePart,
        submitPart: onSubmitPart,
        resetPart: onResetPart,
        requestHint: onRequestHint,
        submitEvaluations: onSubmitEvaluations,
        activityReady: onReady,
        resizePart: onResize,
        getUserData: readUserData,
        setUserData: saveUserData,
    };
    const [isReady, setIsReady] = useState(false);
    const [model, setModel] = useState('');
    const [state, setState] = useState('');
    useEffect(() => {
        // listen at the document level for events coming from activities
        // because using a ref to listen to the specific activity gets messed up
        // with the React render cycle, need to start listening *BEFORE* it renders
        const wcEventHandler = (e) => __awaiter(void 0, void 0, void 0, function* () {
            const { continuation, attemptGuid, partAttemptGuid, payload } = e.detail;
            let isForMe = false;
            const currentAttempt = sharedAttemptStateMap.get(activity.id);
            const currentActivityAllAttempt = AllAttemptStateList.filter((activityAttempt) => activityAttempt.activityId === activity.id && activityAttempt.attemptGuid === attemptGuid);
            if (attemptGuid === currentAttempt.attemptGuid || (currentActivityAllAttempt === null || currentActivityAllAttempt === void 0 ? void 0 : currentActivityAllAttempt.length)) {
                /* console.log('EVENT FOR ME', { e, activity, attempt, currentAttempt }); */
                isForMe = true;
            }
            const handler = bridgeEvents[e.type];
            if (isForMe && handler) {
                const result = yield handler(attemptGuid, partAttemptGuid, payload);
                if (continuation) {
                    continuation(result);
                }
            }
        });
        Object.keys(bridgeEvents).forEach((eventName) => {
            document.addEventListener(eventName, wcEventHandler);
        });
        // send a state snapshot of everything in with the attempt
        // because we need at least read only access to cross activity values and extrinsic
        // *maybe* better to have a onInit callback and send it as a response?
        // because this is BIG
        /* const envSnapshot = getEnvState(defaultGlobalEnv);
        const fullState = { ...attempt, snapshot: envSnapshot }; */
        setState(JSON.stringify(attempt));
        sharedAttemptStateMap.set(activity.id, attempt);
        setModel(JSON.stringify(activity));
        setIsReady(true);
        return () => {
            Object.keys(bridgeEvents).forEach((eventName) => {
                document.removeEventListener(eventName, wcEventHandler);
            });
            setIsReady(false);
            sharedAttemptStateMap.delete(activity.id);
        };
    }, []);
    const ref = useRef(null);
    const lastCheckTriggered = useSelector(selectLastCheckTriggered);
    const lastCheckResults = useSelector(selectLastCheckResults);
    const [checkInProgress, setCheckInProgress] = useState(false);
    const historyModeNavigation = useSelector(selectHistoryNavigationActivity);
    useEffect(() => {
        if (!lastCheckTriggered || !ref.current) {
            return;
        }
        setCheckInProgress(true);
        ref.current.notify(NotificationType.CHECK_STARTED, { ts: lastCheckTriggered });
    }, [lastCheckTriggered]);
    const notifyCheckComplete = (results) => __awaiter(void 0, void 0, void 0, function* () {
        if (!ref.current) {
            return;
        }
        const { snapshot } = yield onRequestLatestState();
        const payload = Object.assign(Object.assign({}, clone(results)), { snapshot });
        setCheckInProgress(false);
        if (!ref.current) {
            return;
        }
        ref.current.notify(NotificationType.CHECK_COMPLETE, payload);
    });
    useEffect(() => {
        if (checkInProgress && lastCheckResults && lastCheckResults.timestamp === lastCheckTriggered) {
            /* console.log('AR Check Effect', { lastCheckTriggered, lastCheckResults }); */
            const currentAttempt = sharedAttemptStateMap.get(activity.id);
            if (currentAttempt.activityId === lastCheckResults.attempt.activityId) {
                sharedAttemptStateMap.set(activity.id, lastCheckResults.attempt);
                AllAttemptStateList.push({
                    activityId: activity === null || activity === void 0 ? void 0 : activity.id,
                    attemptGuid: lastCheckResults.attempt.attemptGuid,
                    attempt: lastCheckResults.attempt,
                });
            }
            notifyCheckComplete(lastCheckResults);
        }
    }, [checkInProgress, lastCheckResults, lastCheckTriggered]);
    // BS: it might not should know about this currentActivityId, though in other layouts maybe (single view)
    // maybe it will just be the same and never actually change.
    // TODO: check if it needs to come from somewhere higher
    const currentActivityId = useSelector(selectCurrentActivityId);
    const initPhaseComplete = useSelector(selectInitPhaseComplete);
    const initStateFacts = useSelector(selectInitStateFacts);
    const currentActivityTree = useSelector(selectCurrentActivityTree);
    const updateGlobalState = (snapshot, stateFacts) => __awaiter(void 0, void 0, void 0, function* () {
        const payloadData = {};
        stateFacts.map((fact) => {
            // EverApp Information
            if (fact.startsWith('app.')) {
                const data = fact.split('.');
                const objId = data.splice(2).join('.');
                const value = snapshot[fact];
                payloadData[data[1]] = Object.assign(Object.assign({}, payloadData[data[1]]), { [objId]: value });
            }
        });
        yield Extrinsic.updateGlobalUserState(payloadData, isPreviewMode);
    });
    const notifyContextChanged = () => __awaiter(void 0, void 0, void 0, function* () {
        // even though ActivityRenderer still lives inside the main react app ecosystem
        // it can't logically access the "localized" version of the state snapshot
        // because this is a single activity and doesn't know about Layout (Deck View) behavior
        // so it needs to ask the parent for it.
        const { snapshot } = yield onRequestLatestState();
        updateGlobalState(snapshot, initStateFacts);
        const finalInitSnapshot = initStateFacts.reduce((acc, key) => {
            let target = key;
            if (target.indexOf('stage') === 0) {
                const lstVar = target.split('.');
                if ((lstVar === null || lstVar === void 0 ? void 0 : lstVar.length) > 1) {
                    const ownerActivity = currentActivityTree === null || currentActivityTree === void 0 ? void 0 : currentActivityTree.find((activity) => !!activity.content.partsLayout.find((p) => p.id === lstVar[1]));
                    target = ownerActivity ? `${ownerActivity.id}|${target}` : `${target}`;
                }
            }
            const originalValue = snapshot[target];
            const typeOfOriginalValue = typeof originalValue;
            const evaluatedValue = typeOfOriginalValue === 'string'
                ? templatizeText(originalValue, snapshot, defaultGlobalEnv, true)
                : originalValue;
            acc[key] = evaluatedValue;
            return acc;
        }, {});
        ref.current.notify(NotificationType.CONTEXT_CHANGED, {
            currentActivityId,
            mode: historyModeNavigation ? contexts.REVIEW : contexts.VIEWER,
            snapshot,
            initStateFacts: finalInitSnapshot,
            domain: adaptivityDomain,
        });
    });
    useEffect(() => {
        if (!initPhaseComplete || !ref.current) {
            return;
        }
        notifyContextChanged();
    }, [initPhaseComplete]);
    const mutationTriggered = useSelector(selectLastMutateTriggered);
    const mutateChanges = useSelector(selectLastMutateChanges);
    const notifyStateMutation = () => __awaiter(void 0, void 0, void 0, function* () {
        ref.current.notify(NotificationType.STATE_CHANGED, {
            mutateChanges,
        });
    });
    useEffect(() => {
        if (!mutationTriggered || !ref.current) {
            return;
        }
        notifyStateMutation();
    }, [mutationTriggered]);
    const handleStateChangeEvents = (changes) => __awaiter(void 0, void 0, void 0, function* () {
        var _c;
        if (!ref.current) {
            return;
        }
        const currentStateSnapshot = {};
        if (((_c = changes === null || changes === void 0 ? void 0 : changes.changed) === null || _c === void 0 ? void 0 : _c.length) > 1) {
            changes.changed.forEach((element, index) => {
                if (index > 0) {
                    const variable = element.split(`${currentActivityId}|`);
                    const variableName = (variable === null || variable === void 0 ? void 0 : variable.length) > 1 ? variable[1] : element;
                    currentStateSnapshot[variableName] = getValue(element, defaultGlobalEnv);
                }
            });
            if (Object.keys(currentStateSnapshot).length > 0) {
                ref.current.notify(NotificationType.STATE_CHANGED, {
                    mutateChanges: currentStateSnapshot,
                });
            }
        }
    });
    useEffect(() => {
        defaultGlobalEnv.addListener('change', handleStateChangeEvents);
        return () => {
            defaultGlobalEnv.removeListener('change', handleStateChangeEvents);
        };
    }, [activity.id]);
    const elementProps = {
        ref,
        graded: false,
        model,
        state,
        preview: isPreviewMode,
        progressState: 'progressState',
        userId: currentUserId,
        onSaveActivity,
        onSubmitActivity,
        onRequestHint,
        onResetActivity,
        onResetPart,
        onSavePart,
        onSubmitEvaluations,
        onSubmitPart,
        onReady,
        onResize,
        onSetData: saveUserData,
        onGetData: readUserData,
    };
    // don't render until we're already listening!
    if (!isReady) {
        return null;
    }
    return React.createElement((_a = activity.activityType) === null || _a === void 0 ? void 0 : _a.delivery_element, elementProps, null);
};
export default ActivityRenderer;
//# sourceMappingURL=ActivityRenderer.jsx.map