import React from 'react';
import { useSelector } from 'react-redux';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { renderPartFeedback } from 'components/activities/common/delivery/evaluation/Evaluation';
import { ActivityDeliveryState } from 'data/activities/DeliveryState';

export type FocusedFeedbackProps = {
  focusedPart: string | null;
};

export const FocusedFeedback: React.FC<FocusedFeedbackProps> = (props: FocusedFeedbackProps) => {
  const { focusedPart } = props;
  const {
    mode,
    context: { graded, surveyId, showFeedback },
    writerContext,
  } = useDeliveryElementContext();
  const uiState = useSelector((state: ActivityDeliveryState) => state);

  // if this is within a survey or if it is graded but not in review mode, do not show feedback
  if (surveyId || (graded && mode !== 'review') || showFeedback == false) {
    return null;
  }

  if (graded) {
    // if we are showing feedback in a graded review context, render all part feedbacks
    return (
      <React.Fragment>
        {uiState.attemptState.parts.map((part) => (
          <React.Fragment key={part.partId}>
            {renderPartFeedback(part, writerContext, true)}
          </React.Fragment>
        ))}
      </React.Fragment>
    );
  } else {
    // otherwise, only render the currently focused part feedback
    const part = uiState.attemptState.parts.find((ps) => ps.partId === focusedPart);
    return part !== undefined ? renderPartFeedback(part, writerContext, true) : null;
  }
};
