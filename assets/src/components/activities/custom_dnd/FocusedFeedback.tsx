import { renderPartFeedback } from 'components/activities/common/delivery/evaluation/Evaluation';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { ActivityDeliveryState } from 'data/activities/DeliveryState';
import React from 'react';
import { useSelector } from 'react-redux';

export type FocusedFeedbackProps = {
  focusedPart: string | null;
};

export const FocusedFeedback: React.FC<FocusedFeedbackProps> = (props: FocusedFeedbackProps) => {
  const { focusedPart } = props;
  const { graded, mode, surveyId, writerContext } = useDeliveryElementContext();
  const uiState = useSelector((state: ActivityDeliveryState) => state);

  // If not item is selected, or this is within a survey, or if it is graded but not in review mode, do not show feedback
  if (focusedPart === null || surveyId !== undefined || (graded && mode !== 'review')) {
    return null;
  }

  const part = uiState.attemptState.parts.find((ps) => ps.partId === focusedPart);
  return part !== undefined ? renderPartFeedback(part, writerContext) : null;
};
