import React from 'react';
import { useSelector } from 'react-redux';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { isOneAtATimeScoreAtTheEndDelivery } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { GradedPoints } from 'components/activities/common/delivery/graded_points/GradedPoints';
import { Checkmark } from 'components/misc/icons/Checkmark';
import { Cross } from 'components/misc/icons/Cross';
import { ActivityDeliveryState } from 'data/activities/DeliveryState';
import { isCorrect } from 'data/activities/utils';

export const GradedPointsConnected: React.FC = () => {
  const { context, mode } = useDeliveryElementContext();
  const { graded, surveyId, showFeedback } = context;
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  return (
    <GradedPoints
      shouldShow={
        showFeedback == true &&
        uiState.attemptState.score !== null &&
        graded &&
        surveyId === null &&
        uiState.activityContext.batchScoring &&
        !isOneAtATimeScoreAtTheEndDelivery(context, mode)
      }
      icon={isCorrect(uiState.attemptState) ? <Checkmark /> : <Cross />}
      attemptState={uiState.attemptState}
    />
  );
};
