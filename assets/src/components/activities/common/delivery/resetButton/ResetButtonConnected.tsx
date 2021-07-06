import { ResetButton } from 'components/activities/common/delivery/resetButton/ResetButton';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import {
  ActivityDeliveryState,
  isEvaluated,
  resetAction,
} from 'data/content/activities/DeliveryState';
import React from 'react';
import { useDispatch, useSelector } from 'react-redux';

interface Props {
  onReset: () => void;
}
export const ResetButtonConnected: React.FC<Props> = ({ onReset }) => {
  const { graded } = useDeliveryElementContext();
  const uiState = useSelector((state: ActivityDeliveryState) => state);

  return (
    <ResetButton
      shouldShow={isEvaluated(uiState) && !graded}
      disabled={!uiState.attemptState.hasMoreAttempts}
      action={onReset}
    />
  );
};
