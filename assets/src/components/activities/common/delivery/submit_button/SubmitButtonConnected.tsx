import { SubmitButton } from 'components/activities/common/delivery/submit_button/SubmitButton';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import {
  ActivityDeliveryState,
  isEvaluated,
  isSubmitted,
  submit,
} from 'data/activities/DeliveryState';
import React from 'react';
import { useDispatch, useSelector } from 'react-redux';

interface Props {
  disabled?: boolean;
}
export const SubmitButtonConnected: React.FC<Props> = ({ disabled }) => {
  const { graded, onSubmitActivity } = useDeliveryElementContext();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();
  return (
    <SubmitButton
      shouldShow={!isEvaluated(uiState) && !isSubmitted(uiState) && !graded}
      disabled={
        disabled === undefined
          ? Object.values(uiState.partState)
              .map((partState) => partState.studentInput)
              .every((input) => input.length === 0)
          : disabled
      }
      onClick={() => dispatch(submit(onSubmitActivity))}
    />
  );
};
