/* eslint-disable react/prop-types */
import { defaultGlobalEnv, getValue } from 'adaptivity/scripting';
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
  makeFeedback,
  PartResponse,
  PartState,
  StudentResponse,
  Success,
} from 'components/activities/types';
import { Environment } from 'janus-script';
import React, { useEffect, useRef, useState } from 'react';
import { useSelector } from 'react-redux';
import { clone } from 'utils/common';
import { contexts } from '../../../types/applicationContext';
import { selectCurrentActivityId } from '../store/features/activities/slice';
import {
  CheckResults,
  selectHistoryNavigationActivity,
  selectInitPhaseComplete,
  selectInitStateFacts,
  selectLastCheckResults,
  selectLastCheckTriggered,
  selectLastMutateChanges,
  selectLastMutateTriggered,
} from '../store/features/adaptivity/slice';
import { debounce } from 'lodash';
import * as Extrinsic from 'data/persistence/extrinsic';
import { selectPreviewMode, selectUserId } from '../store/features/page/slice';
import { NotificationType } from './NotificationContext';
import { selectCurrentActivityTree } from '../store/features/groups/selectors/deck';
import { templatizeText } from './TextParser';
import { CapiVariableTypes } from 'adaptivity/capi';

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
}) => {
  const isPreviewMode = useSelector(selectPreviewMode);
  const currentUserId = useSelector(selectUserId);

  const saveUserData = async (attemptGuid: string, partAttemptGuid: string, payload: any) => {
    const objId = `${payload.key}`;
    await debouncedSaveData({ isPreviewMode, payload, objId, value: payload.value });
  };

  const readUserData = async (attemptGuid: string, partAttemptGuid: string, payload: any) => {
    // Read only the key from the simid
    const objId = `${payload.key}`;
    const data = await debouncedReadData({ isPreviewMode, payload, objId });
    return data;
  };

  const debouncedReadData = debounce(
    async ({ isPreviewMode, payload, objId }) => {
      const retrievedData = await Extrinsic.readGlobalUserState([payload.simId], isPreviewMode);
      return retrievedData?.[payload.simId]?.[objId];
    },
    500,
    { maxWait: 10000, leading: true, trailing: false },
  );

  const debouncedSaveData = debounce(
    async ({ isPreviewMode, payload, objId, value }) => {
      await Extrinsic.updateGlobalUserState({ [payload.simId]: { [objId]: value } }, isPreviewMode);
    },
    200,
    { maxWait: 10000, leading: true, trailing: false },
  );

  const activityState: ActivityState = {
    attemptGuid: 'foo',
    attemptNumber: 1,
    dateEvaluated: null,
    score: null,
    outOf: null,
    parts: [],
    hasMoreAttempts: true,
    hasMoreHints: true,
  };

  const partState: PartState = {
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

  const onReady = async (attemptGuid: string) => {
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
        /* console.log('EVENT FOR ME', { e, activity, attempt, currentAttempt }); */
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
  useEffect(() => {
    if (!lastCheckTriggered || !ref.current) {
      return;
    }
    setCheckInProgress(true);
    ref.current.notify(NotificationType.CHECK_STARTED, { ts: lastCheckTriggered });
  }, [lastCheckTriggered]);

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
    ref.current.notify(NotificationType.CHECK_COMPLETE, payload);
  };

  useEffect(() => {
    if (checkInProgress && lastCheckResults && lastCheckResults.timestamp === lastCheckTriggered) {
      /* console.log('AR Check Effect', { lastCheckTriggered, lastCheckResults }); */
      const currentAttempt = sharedAttemptStateMap.get(activity.id);
      if (currentAttempt.activityId === lastCheckResults.attempt.activityId) {
        sharedAttemptStateMap.set(activity.id, lastCheckResults.attempt);
        AllAttemptStateList.push({
          activityId: activity?.id,
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
  const updateGlobalState = async (snapshot: any, stateFacts: any) => {
    const payloadData = {} as any;
    Object.keys(stateFacts).map((fact: string) => {
      // EverApp Information
      if (fact.startsWith('app.')) {
        const data = fact.split('.');
        const objId = data.splice(2).join('.');
        const value = snapshot[fact];
        payloadData[data[1]] = { ...payloadData[data[1]], [objId]: value };
      }
    });
    await Extrinsic.updateGlobalUserState(payloadData, isPreviewMode);
  };

  const notifyContextChanged = async () => {
    // even though ActivityRenderer still lives inside the main react app ecosystem
    // it can't logically access the "localized" version of the state snapshot
    // because this is a single activity and doesn't know about Layout (Deck View) behavior
    // so it needs to ask the parent for it.
    const { snapshot } = await onRequestLatestState();

    updateGlobalState(snapshot, initStateFacts);
    const finalInitSnapshot = Object.keys(initStateFacts).reduce((acc: any, key: string) => {
      let target = key;
      if (target.indexOf('stage') === 0) {
        const lstVar = target.split('.');
        if (lstVar?.length > 1) {
          const ownerActivity = currentActivityTree?.find(
            (activity) => !!activity.content.partsLayout.find((p: any) => p.id === lstVar[1]),
          );
          target = ownerActivity ? `${ownerActivity.id}|${target}` : `${target}`;
        }
      }
      acc[key] = snapshot[target];
      return acc;
    }, {});
    ref.current.notify(NotificationType.CONTEXT_CHANGED, {
      currentActivityId,
      mode: historyModeNavigation ? contexts.REVIEW : contexts.VIEWER,
      snapshot,
      initStateFacts: finalInitSnapshot,
      domain: adaptivityDomain,
    });
  };

  useEffect(() => {
    if (!initPhaseComplete || !ref.current) {
      return;
    }
    notifyContextChanged();
  }, [initPhaseComplete]);

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
  return React.createElement(activity.activityType?.delivery_element, elementProps, null);
};

export default ActivityRenderer;
