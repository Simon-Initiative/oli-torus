import React from 'react';
import { useSelector } from 'react-redux';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { ResetButton } from 'components/activities/common/delivery/reset_button/ResetButton';
import { ActivityDeliveryState, isEvaluated, isSubmitted } from 'data/activities/DeliveryState';

interface Props {
  onReset: () => void;
  hideBeforeSubmit?: boolean;
}
export const ResetButtonConnected: React.FC<Props> = ({ onReset, hideBeforeSubmit }) => {
  const { graded, surveyId } = useDeliveryElementContext().context;
  const uiState = useSelector((state: ActivityDeliveryState) => state);

  const disabled = !uiState.attemptState.hasMoreAttempts;
  const evaluated = (isEvaluated(uiState) || isSubmitted(uiState)) && !graded && surveyId === null;

  // If the activity is graded or a survey, then we should never show the reset button.
  // If the hideBeforeSubmit flag is set, then we should only show the reset button if the activity has been submitted.
  // If the hideBeforeSubmit flag is not set, then we should always show the reset button, but disable it if the activity has been submitted.
  const shouldShow = hideBeforeSubmit ? evaluated : !graded && surveyId === null;
  const shouldDisable = hideBeforeSubmit ? disabled : !evaluated || disabled;

  return <ResetButton shouldShow={shouldShow} disabled={shouldDisable} action={onReset} />;
};

ResetButtonConnected.defaultProps = {
  hideBeforeSubmit: true,
};
