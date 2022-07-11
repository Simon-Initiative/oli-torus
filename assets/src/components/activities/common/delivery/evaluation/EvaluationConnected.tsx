import { Evaluation } from 'components/activities/common/delivery/evaluation/Evaluation';
import { Submission } from 'components/activities/common/delivery/evaluation/Submission';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { ActivityDeliveryState, isEvaluated, isSubmitted } from 'data/activities/DeliveryState';
import React from 'react';
import { useSelector } from 'react-redux';

export const EvaluationConnected: React.FC = () => {
  const { graded, mode, surveyId, writerContext } = useDeliveryElementContext();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  console.log('surveyId', surveyId, uiState);
  return (
    <>
      <Evaluation
        shouldShow={
          isEvaluated(uiState) && (!graded || mode === 'review') && surveyId === undefined
        }
        attemptState={uiState.attemptState}
        context={writerContext}
      />
      <Submission attemptState={uiState.attemptState} surveyId={surveyId} />
    </>
  );
};
