import { SubmitButton } from 'components/activities/common/delivery/submitButton/SubmitButton';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { ActivityDeliveryState, isEvaluated, submit } from 'data/content/activities/DeliveryState';
import React from 'react';
import { useDispatch, useSelector } from 'react-redux';

interface Props {
  disabled?: boolean;
}
export const SubmitButtonConnected: React.FC<Props> = ({ disabled }) => {
  const { graded, onSubmitActivity } = useDeliveryElementContext();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  console.log('selection', uiState.selection);
  const dispatch = useDispatch();
  return (
    <SubmitButton
      shouldShow={!isEvaluated(uiState) && !graded}
      disabled={disabled === undefined ? uiState.selection.length === 0 : disabled}
      onClick={() => dispatch(submit(onSubmitActivity))}
    />
  );
};
