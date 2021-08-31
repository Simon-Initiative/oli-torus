import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import {
  getCorrectResponse,
  getIncorrectResponse,
} from 'components/activities/common/responses/authoring/responseUtils';
import { FeedbackCard } from 'components/activities/common/responses/FeedbackCard';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { HasParts, RichText } from 'components/activities/types';
import React from 'react';

interface Props {
  partId: string;
  children: React.ReactNode | ((xs: ReturnType<typeof useSimpleFeedback>) => React.ReactNode);
}

export const useSimpleFeedback = (partId: string) => {
  const { model, dispatch } = useAuthoringElementContext<HasParts>();

  return {
    correctResponse: getCorrectResponse(model, partId),
    incorrectResponse: getIncorrectResponse(model, partId),
    updateFeedback: (id: string, content: RichText) =>
      dispatch(ResponseActions.editResponseFeedback(id, content)),
  };
};

export const SimpleFeedback: React.FC<Props> = ({ children, partId }) => {
  const { correctResponse, incorrectResponse, updateFeedback } = useSimpleFeedback(partId);

  if (typeof children === 'function') {
    return children({ correctResponse, incorrectResponse, updateFeedback });
  }

  return (
    <>
      <FeedbackCard
        title="Feedback for correct answer"
        feedback={correctResponse.feedback}
        update={(_id, content) => updateFeedback(correctResponse.id, content)}
        placeholder="Encourage students or explain why the answer is correct"
      />
      <FeedbackCard
        title="Feedback for incorrect answers"
        feedback={incorrectResponse.feedback}
        update={(_id, content) => updateFeedback(incorrectResponse.id, content)}
        placeholder="Enter catch-all feedback for incorrect answers"
      />
      {children}
    </>
  );
};
