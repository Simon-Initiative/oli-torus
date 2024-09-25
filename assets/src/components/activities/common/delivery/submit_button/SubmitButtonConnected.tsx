import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { SubmitButton } from 'components/activities/common/delivery/submit_button/SubmitButton';
import { ActivityDeliveryState, isSubmitted, submit } from 'data/activities/DeliveryState';

export interface SubmitButtonConnectedProps {
  disabled?: boolean;
  hideOnSubmitted?: boolean;
  label?: string;
}
export const SubmitButtonConnected: React.FC<SubmitButtonConnectedProps> = (props) => {
  const { context, onSubmitActivity } = useDeliveryElementContext();
  const { graded, surveyId } = context;
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  const disabled =
    props.disabled === undefined
      ? Object.values(uiState.partState)
          .map((partState) => partState.studentInput)
          .every((input) => input.length === 0)
      : props.disabled;

  const notGradedOrSurvey = !graded && surveyId === null;
  const shouldShowFlag = !isSubmitted(uiState) && notGradedOrSurvey;

  // If the activity is graded or a survey, then we should never show the submit button.
  // If the hideOnSubmitted flag is set, then we should only show the submit button if the activity has not been submitted.
  // If the hideOnSubmitted flag is not set, then we should always show the submit button, but disable it if the activity has been submitted.
  const shouldShow = props.hideOnSubmitted ? shouldShowFlag : notGradedOrSurvey;
  const shouldDisable = props.hideOnSubmitted ? disabled : !shouldShowFlag || disabled;

  return (
    <SubmitButton
      shouldShow={shouldShow}
      disabled={shouldDisable}
      onClick={() => dispatch(submit(onSubmitActivity))}
      label={props.label}
    />
  );
};

SubmitButtonConnected.defaultProps = {
  hideOnSubmitted: true,
};
