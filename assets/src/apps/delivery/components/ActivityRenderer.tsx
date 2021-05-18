/* eslint-disable react/prop-types */
import {
  DeliveryElementProps,
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
import React, { useEffect, useRef } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { selectPreviewMode } from '../store/features/page/slice';
import { selectActivtyAttemptState } from '../store/features/attempt/slice';
import { savePartState } from '../store/features/attempt/actions/savePart';

interface ActivityRendererProps {
  activity: ActivityModelSchema;
  onActivitySave?: any;
  onActivitySubmit?: any;
  onActivityReset?: any;
  onActivitySavePart?: any;
  onActivitySubmitPart?: any;
  onActivityResetPart?: any;
  onActivityRequestHint?: any;
  onActivitySubmitEvaluations?: any;
}

const defaultHandler = async () => true;

const ActivityRenderer: React.FC<ActivityRendererProps> = ({
  activity,
  onActivitySave = defaultHandler,
  onActivitySubmit = defaultHandler,
  onActivityReset = defaultHandler,
  onActivitySavePart = defaultHandler,
  onActivitySubmitPart = defaultHandler,
  onActivityRequestHint = defaultHandler,
  onActivityResetPart = defaultHandler,
  onActivitySubmitEvaluations = defaultHandler,
}) => {
  const dispatch = useDispatch();
  const isPreviewMode = useSelector(selectPreviewMode);
  const currentUserId = 1; // TODO from state

  const currentAttemptState = useSelector((state) =>
    selectActivtyAttemptState(state, activity.resourceId),
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

  const wcEventHandler = async (e: CustomEvent) => {
    const handler = bridgeEvents[e.type];
    if (handler) {
      const { continuation, attemptGuid, partAttemptGuid, payload } = e.detail;
      const result = await handler(attemptGuid, partAttemptGuid, payload);
      if (continuation) {
        continuation(result);
      }
    }
  };

  const ref = useRef(null);
  useEffect(() => {
    if (ref.current) {
      const wc = ref.current as any;
      Object.keys(bridgeEvents).forEach((eventName) => {
        wc.addEventListener(eventName, wcEventHandler);
      });
    }
    return () => {
      if (ref.current) {
        const wc = ref.current as any;
        Object.keys(bridgeEvents).forEach((eventName) => {
          wc.removeEventListener(eventName, wcEventHandler);
        });
      }
    };
  }, [ref.current]);

  const elementProps = {
    ref,
    graded: false,
    model: JSON.stringify(activity),
    state: JSON.stringify(currentAttemptState),
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

  return React.createElement(activity.activityType?.delivery_element, elementProps, null);
};

export default ActivityRenderer;
