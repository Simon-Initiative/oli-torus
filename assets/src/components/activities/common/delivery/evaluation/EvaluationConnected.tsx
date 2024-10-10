import React from 'react';
import { useSelector } from 'react-redux';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { Evaluation } from 'components/activities/common/delivery/evaluation/Evaluation';
import { Submission } from 'components/activities/common/delivery/evaluation/Submission';
import { ActivityDeliveryState, isEvaluated } from 'data/activities/DeliveryState';

export const EvaluationConnected: React.FC = () => {
  const { context, writerContext } = useDeliveryElementContext();
  const { surveyId } = context;
  const uiState = useSelector((state: ActivityDeliveryState) => state);

  return (
    <>
      <Evaluation
        shouldShow={context.showFeedback == true && isEvaluated(uiState) && surveyId === null}
        attemptState={uiState.attemptState}
        showExplanation={context.showExplanation}
        context={writerContext}
      />
      <Submission attemptState={uiState.attemptState} surveyId={surveyId} />
    </>
  );
};
