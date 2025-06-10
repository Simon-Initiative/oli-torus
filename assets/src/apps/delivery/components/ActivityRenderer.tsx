import React, { useCallback, useEffect, useRef, useState } from 'react';
import { useSelector } from 'react-redux';
import { Environment } from 'janus-script';
import {
  EvaluationResponse,
  PartActivityResponse,
  RequestHintResponse,
  ResetActivityResponse,
} from 'components/activities/DeliveryElement';
import {
  ActivityModelSchema,
  ActivityState,
  ClientEvaluation,
  PartResponse,
  PartState,
  StudentResponse,
  Success,
  makeFeedback,
} from 'components/activities/types';
import { CapiVariableTypes } from 'adaptivity/capi';
import { defaultGlobalEnv, evalScript, getValue, templatizeText } from 'adaptivity/scripting';
import * as Extrinsic from 'data/persistence/extrinsic';
import { clone } from 'utils/common';
import { contexts } from '../../../types/applicationContext';
import { handleValueExpression } from '../layouts/deck/DeckLayoutFooter';
import { selectCurrentActivityId } from '../store/features/activities/slice';
import {
  CheckResults,
  selectHistoryNavigationActivity,
  selectInitPhaseComplete,
  selectLastCheckResults,
  selectLastCheckTriggered,
  selectLastMutateChanges,
  selectLastMutateTriggered,
} from '../store/features/adaptivity/slice';
import { selectCurrentActivityTree } from '../store/features/groups/selectors/deck';
import {
  selectPageSlug,
  selectPreviewMode,
  selectReviewMode,
  selectSectionSlug,
  selectUserId,
} from '../store/features/page/slice';
import { NotificationType } from './NotificationContext';

interface ActivityRendererProps {
  activity: ActivityModelSchema;
  attempt: ActivityState;
  onActivitySave?: any;
  onActivitySubmit?: any;
  onActivityReset?: any;
  onActivitySavePart?: any;
  onActivitySubmitPart?: any;
  onActivityResetPart?: any;
  onActivityRequestHint?: any;
  onActivitySubmitEvaluations?: any;
  onActivityReady?: any;
  onRequestLatestState?: any;
  adaptivityDomain?: string; // currently 'stage' or 'app'
  isEverApp?: boolean;
  blobStorageProvider: 'deprecated' | 'new';
}

const defaultHandler = async () => {
  /* console.log('DEFAULT HANDLER AR'); */
  return true;
};

// because of events and function references, we need to store state outside of the function
const sharedAttemptStateMap = new Map();

const AllAttemptStateList: {
  activityId: string | undefined;
  attemptGuid: string;
  attempt: unknown;
}[] = [];
// the activity renderer should be capable of handling *any* activity type, not just adaptive
// most events should be simply bubbled up to the layout renderer for handling
const ActivityRenderer: React.FC<ActivityRendererProps> = ({
  activity,
  attempt,
  onActivitySave = defaultHandler,
  onActivitySubmit = defaultHandler,
  onActivityReset = defaultHandler,
  onActivitySavePart = defaultHandler,
  onActivitySubmitPart = defaultHandler,
  onActivityRequestHint = defaultHandler,
  onActivityResetPart = defaultHandler,
  onActivitySubmitEvaluations = defaultHandler,
  onActivityReady = defaultHandler,
  onRequestLatestState = async () => ({ snapshot: {} }),
  adaptivityDomain = 'stage',
  isEverApp = false,
  blobStorageProvider,
}) => {
  const isPreviewMode = useSelector(selectPreviewMode);
  const isReviewMode = useSelector(selectReviewMode);
  const currentUserId = useSelector(selectUserId);
  const currentLessonId = useSelector(selectPageSlug);
  const sectionSlug = useSelector(selectSectionSlug);
  const saveUserData = async (attemptGuid: string, partAttemptGuid: string, payload: any) => {
    if (isReviewMode) {
      return;
    }
    const { simId, key, value } = payload;
    await Extrinsic.updateGlobalUserState(
      blobStorageProvider,
      { [simId]: { [key]: value } },
      isPreviewMode,
    );
    try {
      // Review mode requires the ever app variable to be fetched from Resourse Attempt state so we need to update the variable in scripting so that
      // when trigger check happens, the extrinsic state get updated and sent to server. Adding it in try catch to avoid any failure during the scripting update which
      //might cause the Ever app to not function correctly.
      const script = `let {${`app.${simId}.${key}`}} = ${JSON.stringify(value)}`;
      evalScript(script, defaultGlobalEnv);
    } catch (ex) {
      //Do nothing
    }
  };

  const readUserData = async (attemptGuid: string, partAttemptGuid: string, payload: any) => {
    const { simId, key } = payload;
    if (isReviewMode) {
      const { snapshot } = await onRequestLatestState();
      const keyData = snapshot[`app.${simId}.${key}`];
      if (keyData) {
        return keyData;
      }
      return undefined;
    }
    const data = await Extrinsic.readGlobalUserState(blobStorageProvider, [simId], isPreviewMode);
    if (data) {
      const value = data[simId]?.[key];
      /* console.log('GOT DATA', { simId, key, value, data }); */
      return value;
    }
    return undefined;
  };

  const activityState: ActivityState = {
    attemptGuid: 'foo',
    attemptNumber: 1,
    dateEvaluated: null,
    dateSubmitted: null,
    score: null,
    outOf: null,
    parts: [],
    hasMoreAttempts: true,
    hasMoreHints: true,
    groupId: null,
  };

  const partState: PartState = {
    attemptGuid: 'TODO1234',
    attemptNumber: 1,
    dateEvaluated: null,
    dateSubmitted: null,
    score: null,
    outOf: null,
    response: '',
    feedback: makeFeedback(''),
    explanation: null,
    hints: [],
    partId: 1,
    hasMoreAttempts: false,
    hasMoreHints: false,
  };

  const onSaveActivity = async (attemptGuid: string, partResponses: PartResponse[]) => {
    await onActivitySave(activity.id, attemptGuid, partResponses);
    // TODO: use something from parent call to determine if is actually a success
    const result: Success = {
      type: 'success',
    };
    return result;
  };

  const onSubmitActivity = async (attemptGuid: string, partResponses: PartResponse[]) => {
    await onActivitySubmit(activity.id, attemptGuid, partResponses);
    // TODO: use something from parent call to determine if is actually a success
    const result: EvaluationResponse = {
      type: 'success',
      actions: [],
    };
    return result;
  };

  const onResetActivity = async (attemptGuid: string) => {
    await onActivityReset(activity.id, attemptGuid);
    // TODO
    const result: ResetActivityResponse = {
      type: 'success',
      attemptState: activityState,
      model: activity,
    };
    return result;
  };

  const onRequestHint = async (attemptGuid: string, partAttemptGuid: string) => {
    await onActivityRequestHint(activity.id, attemptGuid, partAttemptGuid);
    const result: RequestHintResponse = {
      type: 'success',
      hasMoreHints: false,
    };
    return result;
  };

  const onSavePart = async (
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => {
    /* console.log('onSavePart (ActivityRenderer)', { attemptGuid, partAttemptGuid, response }); */

    const result = await onActivitySavePart(activity.id, attemptGuid, partAttemptGuid, response);

    return result;
  };

  const onSubmitPart = async (
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => {
    await onActivitySubmitPart(activity.id, attemptGuid, partAttemptGuid, response);
    const result: EvaluationResponse = {
      type: 'success',
      actions: [],
    };
    return result;
  };

  const onResetPart = async (attemptGuid: string, partAttemptGuid: string) => {
    await onActivityResetPart(activity.id, attemptGuid, partAttemptGuid);
    const result: PartActivityResponse = {
      type: 'success',
      attemptState: partState,
    };
    return result;
  };

  const onSubmitEvaluations = async (
    attemptGuid: string,
    clientEvaluations: ClientEvaluation[],
  ) => {
    await onActivitySubmitEvaluations(activity.id, attemptGuid, clientEvaluations);

    const result: EvaluationResponse = {
      type: 'success',
      actions: [],
    };
    return result;
  };

  const onReady = async (attemptGuid: string, partAttemptGuid: string, response: any) => {
    const isResumeMode = getValue('session.isResumeMode', defaultGlobalEnv) || false;
    if (Array.isArray(response) && !isResumeMode) {
      await Promise.all(
        await response.map(async (partResponse) => {
          const partAttemptGuid = partResponse[0];
          const partAttemptResponses = partResponse[1];
          await onActivitySavePart(activity.id, attemptGuid, partAttemptGuid, partAttemptResponses);
        }),
      );
    }

    const results = await onActivityReady(activity.id, attemptGuid);
    const result: Success = {
      type: 'success',
    };
    // provide each activity with a local scope based on the global scope
    // should allow it to do some same screen interactivity/adaptivity
    const activityScriptEnv = new Environment(defaultGlobalEnv);
    /* evalScript(`let global.screenId = "${activity.id}"`, activityScriptEnv); */
    // BS: TODO make compatible with *any* activity
    return { ...results, ...result, env: activityScriptEnv, domain: adaptivityDomain };
  };

  const onResize = async (attemptGuid: string) => {
    // no need to do anything for now.
    /*  console.log('onResize called'); */
  };

  const bridgeEvents: Record<string, any> = {
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
    const wcEventHandler = async (e: CustomEvent) => {
      const { continuation, attemptGuid, partAttemptGuid, payload } = e.detail;
      let isForMe = false;

      const currentAttempt = sharedAttemptStateMap.get(activity.id);
      const currentActivityAllAttempt = AllAttemptStateList.filter(
        (activityAttempt) =>
          activityAttempt.activityId === activity.id && activityAttempt.attemptGuid === attemptGuid,
      );

      if (attemptGuid === currentAttempt.attemptGuid || currentActivityAllAttempt?.length) {
        // console.log('EVENT FOR ME', { e, activity, attempt, currentAttempt });
        isForMe = true;
      }
      const handler = bridgeEvents[e.type];
      if (isForMe && handler) {
        const result = await handler(attemptGuid, partAttemptGuid, payload);
        if (continuation) {
          continuation(result);
        }
      }
    };

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

  const ref = useRef<any>(null);

  const lastCheckTriggered = useSelector(selectLastCheckTriggered);
  const lastCheckResults = useSelector(selectLastCheckResults);
  const [checkInProgress, setCheckInProgress] = useState(false);
  const historyModeNavigation = useSelector(selectHistoryNavigationActivity);
  const reviewMode = useSelector(selectReviewMode);
  useEffect(() => {
    if (!lastCheckTriggered || !ref.current) {
      return;
    }
    setCheckInProgress(true);
    ref.current.notify(NotificationType.CHECK_STARTED, { ts: lastCheckTriggered });
  }, [lastCheckTriggered]);

  const handleInitStateVars = (initState: any, snapshot: any) => {
    const finalInitSnapshot = initState?.reduce((acc: any, initObject: any) => {
      let key = initObject.target;
      let updatedValue = initObject.value;
      const value = initObject.value;
      const typeOfOriginalValue = typeof value;
      if (key.indexOf('stage') === 0) {
        const lstVar = key.split('.');
        if (lstVar?.length > 1) {
          const ownerActivity = currentActivityTree?.find(
            (activity) =>
              !!(activity.content?.partsLayout || []).find((p: any) => p.id === lstVar[1]),
          );
          key = ownerActivity ? `${ownerActivity.id}|${key}` : `${key}`;
        }
      }
      if (initObject.operator === 'bind to') {
        initStateBindToFacts[initObject.target] = snapshot[key] || '';
        return acc;
      } else if (typeOfOriginalValue === 'string') {
        if (
          initObject.type !== CapiVariableTypes.MATH_EXPR &&
          ((value[0] === '{' && value[1] !== '"') ||
            (value.indexOf('{') !== -1 && value.indexOf('}') !== -1))
        ) {
          //this is a expression so we get the value from snapshot because this was already evaluated in deck.ts
          updatedValue = snapshot[key];
        } else {
          updatedValue = initObject.value;
        }
      } else {
        updatedValue = initObject.value;
      }
      if (
        initObject.type !== CapiVariableTypes.MATH_EXPR &&
        updatedValue &&
        updatedValue.toString().indexOf('{') !== -1 &&
        updatedValue.toString().indexOf('}') !== -1
      ) {
        // need handle the value expression i.e. value = MISSION CONTROL: Search the surface of {q:1476902665616:794|stage.simIFrame.Globals.SelectedObject} for the astrocache.
        // otherwise, it will never be replace with actual value on screen
        updatedValue = handleValueExpression(
          currentActivityTree,
          initObject.value,
          initObject.operator,
        );
      }
      const evaluatedValue =
        typeOfOriginalValue === 'string' &&
        initObject.type !== CapiVariableTypes.MATH_EXPR &&
        value.indexOf('{') !== -1 &&
        value.indexOf('}') !== -1
          ? templatizeText(updatedValue, snapshot, defaultGlobalEnv, true, false)
          : updatedValue;
      acc[initObject.target.trim()] = evaluatedValue;
      return acc;
    }, {});
    return finalInitSnapshot;
  };

  const notifyCheckComplete = async (results: CheckResults) => {
    if (!ref.current) {
      return;
    }
    const { snapshot } = await onRequestLatestState();
    const payload = { ...clone(results), snapshot };
    setCheckInProgress(false);
    if (!ref.current) {
      return;
    }
    ref?.current?.notify(NotificationType.CHECK_COMPLETE, payload);
  };

  const hasNavigation = (events: any) => {
    if (!currentActivityTree || !currentActivityTree?.length) {
      return false;
    }
    let eventsToProcess = events.results;
    const actionsByType: any = {
      feedback: [],
      mutateState: [],
      navigation: [],
    };
    const currentActivity = currentActivityTree[currentActivityTree.length - 1];
    const combineFeedback = !!currentActivity?.content?.custom?.combineFeedback;
    if (!combineFeedback) {
      eventsToProcess = [eventsToProcess[0]];
    }
    eventsToProcess.forEach((evt: any) => {
      const { actions } = evt.params;
      actions.forEach((action: any) => {
        actionsByType[action.type].push(action);
      });
    });
    if (actionsByType.navigation.length > 0) {
      const [firstNavAction] = actionsByType.navigation;
      const navTarget = firstNavAction.params.target;
      // check current activity id, not *this* one because it could be a layer
      if (navTarget !== currentActivityId) {
        return true;
      }
    }
    return false;
  };

  const [lastCheckHandledTimestamp, setLastCheckHandledTimestamp] = useState(0);

  useEffect(() => {
    if (lastCheckTriggered === lastCheckHandledTimestamp) {
      return;
    }
    if (checkInProgress && lastCheckResults && lastCheckResults.timestamp === lastCheckTriggered) {
      /* console.log('*********AR Check Effect', {
        lastCheckTriggered,
        lastCheckHandledTimestamp,
        lastCheckResults,
        hasNav: hasNavigation(lastCheckResults),
      }); */
      setLastCheckHandledTimestamp(lastCheckTriggered);
      const currentAttempt = sharedAttemptStateMap.get(activity.id);
      if (currentAttempt.activityId === lastCheckResults.attempt.activityId) {
        sharedAttemptStateMap.set(activity.id, lastCheckResults.attempt);
        AllAttemptStateList.push({
          activityId: activity?.id,
          attemptGuid: lastCheckResults.attempt.attemptGuid,
          attempt: lastCheckResults.attempt,
        });
      }

      const hasNavigationToDifferentActivity = hasNavigation(lastCheckResults);
      if (
        (!hasNavigationToDifferentActivity || isEverApp) &&
        !historyModeNavigation &&
        !reviewMode
      ) {
        notifyCheckComplete(lastCheckResults);
      }
    }
  }, [
    checkInProgress,
    lastCheckResults,
    lastCheckTriggered,
    lastCheckHandledTimestamp,
    historyModeNavigation,
    reviewMode,
  ]);

  // BS: it might not should know about this currentActivityId, though in other layouts maybe (single view)
  // maybe it will just be the same and never actually change.
  // TODO: check if it needs to come from somewhere higher
  const currentActivityId = useSelector(selectCurrentActivityId);
  const initPhaseComplete = useSelector(selectInitPhaseComplete);
  const initStateBindToFacts: any = {};
  const currentActivityTree = useSelector(selectCurrentActivityTree);

  // update all init state facts that target everApps using the app.
  const updateGlobalState = async (snapshot: any, initStates: any[]) => {
    const everAppInits = initStates.filter(
      (initState: any) => initState.target.indexOf('app.') === 0,
    );
    if (everAppInits.length > 0) {
      const payloadData = everAppInits.reduce((data: any, fact: any) => {
        const { target } = fact;
        // EverApp Information
        if (target.startsWith('app.')) {
          const targetParts = target.split('.');
          const objId = targetParts.splice(2).join('.');
          const value = snapshot[target];
          data[targetParts[1]] = { ...data[targetParts[1]], [objId]: value };
        }
        return data;
      }, {});
      /* console.log('updateGlobalState', { payloadData }); */
      await Extrinsic.updateGlobalUserState(blobStorageProvider, payloadData, isPreviewMode);
    }
  };

  const notifyContextChanged = useCallback(async () => {
    /* console.log('notifyContextChanged called'); */
    // even though ActivityRenderer still lives inside the main react app ecosystem
    // it can't logically access the "localized" version of the state snapshot
    // because this is a single activity and doesn't know about Layout (Deck View) behavior
    // so it needs to ask the parent for it.
    const { snapshot } = await onRequestLatestState();

    const currentActivity =
      currentActivityTree && currentActivityTree.length > 0
        ? currentActivityTree[currentActivityTree.length - 1]
        : null;
    const initState = currentActivity?.content?.custom?.facts || [];
    updateGlobalState(snapshot, initState);
    const finalInitSnapshot = handleInitStateVars(initState, snapshot);
    ref.current.notify(NotificationType.CONTEXT_CHANGED, {
      currentActivityId,
      currentLessonId,
      sectionSlug,
      currentUserId,
      mode: historyModeNavigation || reviewMode ? contexts.REVIEW : contexts.VIEWER,
      snapshot,
      initStateFacts: finalInitSnapshot || {},
      domain: adaptivityDomain,
      initStateBindToFacts,
    });
    if (lastCheckResults.timestamp > 0) {
      notifyCheckComplete(lastCheckResults);
    }
  }, [
    historyModeNavigation,
    reviewMode,
    lastCheckResults,
    currentActivityId,
    currentLessonId,
    sectionSlug,
    currentUserId,
  ]);

  const [lastInitPhaseHandledTimestamp, setLastInitPhaseHandledTimestamp] = useState(Date.now());

  useEffect(() => {
    if (!initPhaseComplete || !ref.current || lastInitPhaseHandledTimestamp >= initPhaseComplete) {
      return;
    }
    /* console.log('ActivityRenderer useEffect HANDLED:', {
      initPhaseComplete,
      lastInitPhaseHandledTimestamp,
    }); */
    setLastInitPhaseHandledTimestamp(initPhaseComplete);
    // context change should only be needed for things loaded by parents that are still around
    /* console.log('AR notifyContextChanged', currentActivityId !== activity.id); */
    if (!historyModeNavigation && !reviewMode && currentActivityId !== activity.id) {
      notifyContextChanged();
    }
  }, [
    initPhaseComplete,
    lastInitPhaseHandledTimestamp,
    notifyContextChanged,
    historyModeNavigation,
    currentActivityId,
    reviewMode,
  ]);

  const mutationTriggered = useSelector(selectLastMutateTriggered);
  const mutateChanges = useSelector(selectLastMutateChanges);

  const notifyStateMutation = async () => {
    ref.current.notify(NotificationType.STATE_CHANGED, {
      mutateChanges,
    });
  };

  useEffect(() => {
    if (!mutationTriggered || !ref.current) {
      return;
    }
    notifyStateMutation();
  }, [mutationTriggered]);

  const handleStateChangeEvents = async (changes: any) => {
    if (!ref.current) {
      return;
    }
    const currentStateSnapshot: any = {};
    const appChanges = changes.changed.filter((change: any) => change.includes('app.'));
    if (appChanges.length) {
      // need to write the updated state to the global state
      const updatePayload = appChanges.reduce((data: any, key: string) => {
        const [, everAppId] = key.split('.');
        data[everAppId] = data[everAppId] || {};
        data[everAppId][key.replace(`app.${everAppId}.`, '')] = getValue(key, defaultGlobalEnv);
        return data;
      }, {});
      /* console.log('CHANGE EVENT EVERAPP', { changes, appChanges, updatePayload }); */
      await Extrinsic.updateGlobalUserState(blobStorageProvider, updatePayload, isPreviewMode);
    }
    // we send ALL of the changes to the components
    if (changes?.changed?.length > 1) {
      changes.changed.forEach((element: string, index: number) => {
        if (index > 0) {
          const variable = element.split(`${currentActivityId}|`);
          const variableName = variable?.length > 1 ? variable[1] : element;
          currentStateSnapshot[variableName] = getValue(element, defaultGlobalEnv);
        }
      });

      if (Object.keys(currentStateSnapshot).length > 0) {
        ref.current.notify(NotificationType.STATE_CHANGED, {
          mutateChanges: currentStateSnapshot,
        });
      }
    }
  };

  useEffect(() => {
    defaultGlobalEnv.addListener('change', handleStateChangeEvents);
    console.log('ActivityRenderer mounting', activity.id);
    return () => {
      console.log('ActivityRenderer unmounting', activity.id);
      defaultGlobalEnv.removeListener('change', handleStateChangeEvents);
    };
  }, [activity.id]);

  const elementProps = {
    ref,
    context: JSON.stringify({
      graded: false, // TODO: currently only the page (lesson) has this distinction
      sectionSlug,
      userId: currentUserId,
      groupId: null,
      surveyId: null,
      bibParams: null,
      pageAttemptGuid: '', // TODO: don't think we use this currently, but might be good to have
    }),
    mode: isPreviewMode ? 'preview' : 'delivery', // TODO: review
    model,
    state,
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
  return React.createElement(activity.activityType?.delivery_element, elementProps, null);
};

export default ActivityRenderer;
