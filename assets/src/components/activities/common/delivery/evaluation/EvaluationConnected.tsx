import { Evaluation } from 'components/activities/common/delivery/evaluation/Evaluation';
import { Submission } from 'components/activities/common/delivery/evaluation/Submission';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { ActivityDeliveryState, isEvaluated } from 'data/activities/DeliveryState';
import React from 'react';
import { useSelector } from 'react-redux';

export const EvaluationConnected: React.FC = () => {
  const { context, writerContext } = useDeliveryElementContext();
  const { surveyId } = context;
  const uiState = useSelector((state: ActivityDeliveryState) => state);

  return (
    <>
      <Evaluation
        shouldShow={isEvaluated(uiState) && surveyId === null}
        attemptState={uiState.attemptState}
        context={writerContext}
      />
      <Submission attemptState={uiState.attemptState} surveyId={surveyId} />
    </>
  );
};
