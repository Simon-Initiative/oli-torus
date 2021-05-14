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
import React from 'react';
import { useSelector } from 'react-redux';
import { selectPreviewMode } from '../store/features/page/slice';

interface ActivityRendererProps {
  activity: ActivityModelSchema;
}

const ActivityRenderer: React.FC<ActivityRendererProps> = ({ activity }) => {
  console.log('ACTIVITY', activity);
  const isPreviewMode = useSelector(selectPreviewMode);
  const currentUserId = 1; // TODO from state

  const activityState: ActivityState = {
    attemptGuid: 'TODO1234',
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

  /* const config = activity.content.custom;

  return <PartsLayoutRenderer parts={activity?.content.partsLayout} config={config} />; */

  const onSaveActivity = async (attemptGuid: string, partResponses: PartResponse[]) => {
    const result: Success = {
      type: 'success',
    };
    return result;
  };

  const onSubmitActivity = async (attemptGuid: string, partResponses: PartResponse[]) => {
    const result: EvaluationResponse = {
      type: 'success',
      actions: [],
    };
    return result;
  };

  const onResetActivity = async (attemptGuid: string) => {
    const result: ResetActivityResponse = {
      type: 'success',
      attemptState: activityState,
      model: activity,
    };
    return result;
  };

  const onRequestHint = async (attemptGuid: string, partAttemptGuid: string) => {
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
    const result: Success = {
      type: 'success',
    };
    return result;
  };

  const onSubmitPart = async (
    attemptGuid: string,
    partAttemptGuid: string,
    response: StudentResponse,
  ) => {
    const result: EvaluationResponse = {
      type: 'success',
      actions: [],
    };
    return result;
  };

  const onResetPart = async (attemptGuid: string, partAttemptGuid: string) => {
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
    const result: EvaluationResponse = {
      type: 'success',
      actions: [],
    };
    return result;
  };

  const props = {
    graded: false,
    model: JSON.stringify(activity),
    state: JSON.stringify(activityState),
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
  return React.createElement(activity.activityType?.delivery_element, props, null);
};

export default ActivityRenderer;
