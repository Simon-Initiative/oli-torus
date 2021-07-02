import { Evaluation } from 'components/activities/common/delivery/evaluation/Evaluation';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { ActivityDeliveryState, isEvaluated } from 'data/content/activities/DeliveryState';
import React from 'react';
import { useSelector } from 'react-redux';

export const EvaluationConnected: React.FC = () => {
  const { graded, review, writerContext } = useDeliveryElementContext();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  return (
    <Evaluation
      shouldShow={isEvaluated(uiState) && (!graded || review)}
      attemptState={uiState.attemptState}
      context={writerContext}
    />
  );
};
