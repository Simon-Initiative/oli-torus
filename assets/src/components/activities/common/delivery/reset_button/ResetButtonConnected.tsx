import { ResetButton } from 'components/activities/common/delivery/reset_button/ResetButton';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { ActivityDeliveryState, isEvaluated, isSubmitted } from 'data/activities/DeliveryState';
import React from 'react';
import { useSelector } from 'react-redux';

interface Props {
  onReset: () => void;
}
export const ResetButtonConnected: React.FC<Props> = ({ onReset }) => {
  const { graded } = useDeliveryElementContext();
  const uiState = useSelector((state: ActivityDeliveryState) => state);

  return (
    <ResetButton
      shouldShow={isEvaluated(uiState) && !isSubmitted(uiState) && !graded}
      disabled={!uiState.attemptState.hasMoreAttempts}
      action={onReset}
    />
  );
};
