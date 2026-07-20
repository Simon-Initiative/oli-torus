import React from 'react';
import { useSelector } from 'react-redux';
import type { ActivityContext } from 'components/activities/DeliveryElement';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { Evaluation } from 'components/activities/common/delivery/evaluation/Evaluation';
import { Submission } from 'components/activities/common/delivery/evaluation/Submission';
import type { DeliveryMode } from 'components/activities/types';
import { ActivityDeliveryState, isEvaluated } from 'data/activities/DeliveryState';

export const isOneAtATimeScoreAtTheEndDelivery = (context: ActivityContext, mode: DeliveryMode) =>
  context.graded && mode !== 'review' && context.oneAtATime && context.batchScoring;

export const shouldShowActivityFeedback = (
  context: ActivityContext,
  mode: DeliveryMode,
  evaluated: boolean,
) =>
  context.showFeedback == true &&
  evaluated &&
  context.surveyId === null &&
  !isOneAtATimeScoreAtTheEndDelivery(context, mode);

export const EvaluationConnected: React.FC = () => {
  const { context, mode, writerContext } = useDeliveryElementContext();
  const uiState = useSelector((state: ActivityDeliveryState) => state);

  return (
    <>
      <Evaluation
        shouldShow={shouldShowActivityFeedback(context, mode, isEvaluated(uiState))}
        attemptState={uiState.attemptState}
        context={writerContext}
      />
      <Submission attemptState={uiState.attemptState} surveyId={context.surveyId} />
    </>
  );
};
