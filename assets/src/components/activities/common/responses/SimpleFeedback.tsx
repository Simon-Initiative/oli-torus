import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { FeedbackCard } from 'components/activities/common/responses/FeedbackCard';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { HasParts, RichText } from 'components/activities/types';
import { getCorrectResponse, getIncorrectResponse } from 'data/activities/model/responses';
import React from 'react';

interface Props {
  partId: string;
  children?: (xs: ReturnType<typeof useSimpleFeedback>) => React.ReactElement;
}

export const useSimpleFeedback = (partId: string) => {
  const { model, dispatch } = useAuthoringElementContext<HasParts>();

  return {
    correctResponse: getCorrectResponse(model, partId),
    incorrectResponse: getIncorrectResponse(model, partId),
    updateFeedback: (responseId: string, content: RichText) =>
      dispatch(ResponseActions.editResponseFeedback(responseId, content)),
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
        update={(_id, content) => updateFeedback(correctResponse.id, content as RichText)}
        placeholder="Encourage students or explain why the answer is correct"
      />
      <FeedbackCard
        title="Feedback for incorrect answers"
        feedback={incorrectResponse.feedback}
        update={(_id, content) => updateFeedback(incorrectResponse.id, content as RichText)}
        placeholder="Enter catch-all feedback for incorrect answers"
      />
    </>
  );
};
