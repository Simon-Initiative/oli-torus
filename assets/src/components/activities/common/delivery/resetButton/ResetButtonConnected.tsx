import { ResetButton } from 'components/activities/common/delivery/resetButton/ResetButton';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { ActivityDeliveryState, isEvaluated, reset } from 'data/content/activities/DeliveryState';
import React from 'react';
import { useDispatch, useSelector } from 'react-redux';

export const ResetButtonConnected: React.FC = () => {
  const { graded, onResetActivity } = useDeliveryElementContext();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();
  return (
    <ResetButton
      shouldShow={isEvaluated(uiState) && !graded}
      disabled={!uiState.attemptState.hasMoreAttempts}
      onClick={() => dispatch(reset(onResetActivity))}
    />
  );
};
