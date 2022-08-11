import { GradedPoints } from 'components/activities/common/delivery/graded_points/GradedPoints';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { Checkmark } from 'components/misc/icons/Checkmark';
import { Cross } from 'components/misc/icons/Cross';
import { isCorrect } from 'data/activities/utils';
import { ActivityDeliveryState } from 'data/activities/DeliveryState';
import React from 'react';
import { useSelector } from 'react-redux';

export const GradedPointsConnected: React.FC = () => {
  const { graded, surveyId } = useDeliveryElementContext();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  return (
    <GradedPoints
      shouldShow={uiState.attemptState.score !== null && graded && surveyId === undefined}
      icon={isCorrect(uiState.attemptState) ? <Checkmark /> : <Cross />}
      attemptState={uiState.attemptState}
    />
  );
};
