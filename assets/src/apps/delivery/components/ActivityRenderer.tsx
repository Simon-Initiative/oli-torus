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
import React, { useEffect, useState } from 'react';
import { useSelector } from 'react-redux';
import { defaultGlobalEnv, getEnvState } from '../../../adaptivity/scripting';
import { selectPreviewMode } from '../store/features/page/slice';

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
}

const defaultHandler = async () => {
  return true;
};

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
    console.log('onSavePart (ActivityRenderer)', { attemptGuid, partAttemptGuid, response });

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

  const bridgeEvents: Record<string, any> = {
    saveActivity: onSaveActivity,
    submitActivity: onSubmitActivity,
    resetActivity: onResetActivity,
    savePart: onSavePart,
    submitPart: onSubmitPart,
    resetPart: onResetPart,
    requestHint: onRequestHint,
    submitEvaluations: onSubmitEvaluations,
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
      if (attemptGuid === attempt.attemptGuid) {
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
    const envSnapshot = getEnvState(defaultGlobalEnv);
    const fullState = { ...attempt, snapshot: envSnapshot };
    setState(JSON.stringify(fullState));

    setModel(JSON.stringify(activity));

    setIsReady(true);

    return () => {
      Object.keys(bridgeEvents).forEach((eventName) => {
        document.removeEventListener(eventName, wcEventHandler);
      });
      setIsReady(false);
    };
  }, []);

  const elementProps = {
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
  };

  // don't render until we're already listening!
  if (!isReady) {
    return null;
  }
  return React.createElement(activity.activityType?.delivery_element, elementProps, null);
};

export default ActivityRenderer;
