import { GradedPoints } from 'components/activities/common/delivery/gradedPoints/GradedPoints';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { Checkmark } from 'components/misc/icons/Checkmark';
import { Cross } from 'components/misc/icons/Cross';
import { isCorrect } from 'data/content/activities/activityUtils';
import { ActivityDeliveryState } from 'data/content/activities/DeliveryState';
import React from 'react';
import { useSelector } from 'react-redux';

export const GradedPointsConnected: React.FC = () => {
  const { graded, review } = useDeliveryElementContext();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  return (
    <GradedPoints
      shouldShow={graded && review}
      icon={isCorrect(uiState.attemptState) ? <Checkmark /> : <Cross />}
      attemptState={uiState.attemptState}
    />
  );
};
