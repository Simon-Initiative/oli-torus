import { SubmitButton } from 'components/activities/common/delivery/submitButton/SubmitButton';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { ActivityDeliveryState, isEvaluated, submit } from 'data/content/activities/DeliveryState';
import React from 'react';
import { useDispatch, useSelector } from 'react-redux';

export const SubmitButtonConnected: React.FC = () => {
  const { graded, onSubmitActivity } = useDeliveryElementContext();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();
  return (
    <SubmitButton
      shouldShow={!isEvaluated(uiState) && !graded}
      disabled={uiState.selectedChoices.length === 0}
      onClick={() => dispatch(submit(onSubmitActivity))}
    />
  );
};
