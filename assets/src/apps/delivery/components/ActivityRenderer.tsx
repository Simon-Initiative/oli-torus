/* eslint-disable react/prop-types */
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
} from 'components/activities/types';
import React, { useEffect, useRef, useState } from 'react';
import { useSelector } from 'react-redux';
import { selectCurrentActivityId } from '../store/features/activities/slice';
import {
  selectHistoryNavigationActivity,
  selectInitPhaseComplete,
  selectLastCheckResults,
  selectLastCheckTriggered,
  selectLastMutateChanges,
  selectLastMutateTriggered,
} from '../store/features/adaptivity/slice';
import { selectPreviewMode } from '../store/features/page/slice';
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
}

const defaultHandler = async () => {
  /* console.log('DEFAULT HANDLER AR'); */
  return true;
};

// because of events and function references, we need to store state outside of the function
const sharedAttemptStateMap = new Map();

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
}) => {
  const isPreviewMode = useSelector(selectPreviewMode);
  const currentUserId = 1; // TODO from state

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
    feedback: '',
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
    // BS: TODO make compatible with *any* activity
    return { ...results, ...result };
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
      if (attemptGuid === currentAttempt.attemptGuid) {
        /* console.log('EVENT FOR ME', { e, activity, attempt }); */
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
  useEffect(() => {
    if (!lastCheckTriggered || !ref.current) {
      return;
    }
    setCheckInProgress(true);
    ref.current.notify(NotificationType.CHECK_STARTED, { ts: lastCheckTriggered });
  }, [lastCheckTriggered]);

  useEffect(() => {
    if (checkInProgress && lastCheckResults && lastCheckResults.timestamp === lastCheckTriggered) {
      /* console.log('AR Check Effect', { lastCheckTriggered, lastCheckResults }); */
      const currentAttempt = sharedAttemptStateMap.get(activity.id);
      if (currentAttempt.activityId === lastCheckResults.attempt.activityId) {
        sharedAttemptStateMap.set(activity.id, lastCheckResults.attempt);
      }
      ref.current.notify(NotificationType.CHECK_COMPLETE, lastCheckResults);
      setCheckInProgress(false);
    }
  }, [checkInProgress, lastCheckResults, lastCheckTriggered]);

  // BS: it might not should know about this currentActivityId, though in other layouts maybe (single view)
  // maybe it will just be the same and never actually change.
  // TODO: check if it needs to come from somewhere higher
  const currentActivityId = useSelector(selectCurrentActivityId);
  const initPhaseComplete = useSelector(selectInitPhaseComplete);
  const notifyContextChanged = async () => {
    // even though ActivityRenderer still lives inside the main react app ecosystem
    // it can't logically access the "localized" version of the state snapshot
    // because this is a single activity and doesn't know about Layout (Deck View) behavior
    // so it needs to ask the parent for it.
    const { snapshot } = await onRequestLatestState();
    ref.current.notify(NotificationType.CONTEXT_CHANGED, {
      currentActivityId,
      mode: 'VIEWER', // TODO: based on isPreviewMOde
      snapshot,
    });
  };
  const historyNavigationActivity = useSelector(selectHistoryNavigationActivity);

  useEffect(() => {
    if (!ref.current) {
      return;
    }

    ref.current.notify(NotificationType.HISTORY_NAVIGATION, {
      activityId: historyNavigationActivity,
    });
  }, [historyNavigationActivity]);

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
  };

  // don't render until we're already listening!
  if (!isReady) {
    return null;
  }
  return React.createElement(activity.activityType?.delivery_element, elementProps, null);
};

export default ActivityRenderer;
