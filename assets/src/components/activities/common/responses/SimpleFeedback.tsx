import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { FeedbackCard } from 'components/activities/common/responses/FeedbackCard';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { HasParts, RichText } from 'components/activities/types';
import { getCorrectResponse, getIncorrectResponse } from 'data/activities/model/responses';
import { ShowPage } from './ShowPage';

interface Props {
  partId: string;
}

export const SimpleFeedback: React.FC<Props> = ({ partId }) => {
  const { model, dispatch, editMode, authoringContext } = useAuthoringElementContext<HasParts>();

  const correctResponse = getCorrectResponse(model, partId);
  const incorrectResponse = getIncorrectResponse(model, partId);
  const updateFeedback = (responseId: string, content: RichText) =>
    dispatch(ResponseActions.editResponseFeedback(responseId, content));
  const updateShowPage = (responseId: string, showPage: number | undefined) =>
    dispatch(ResponseActions.editShowPage(responseId, showPage));

  return (
    <>
      <FeedbackCard
        key={`correct-${partId}`}
        title="Feedback for correct answer"
        feedback={correctResponse.feedback}
        update={(_id, content) => updateFeedback(correctResponse.id, content as RichText)}
        placeholder="Encourage students or explain why the answer is correct"
      >
        {authoringContext.contentBreaksExist ? (
          <ShowPage
            editMode={editMode}
            index={correctResponse.showPage}
            onChange={(v) => updateShowPage(correctResponse.id, v)}
          />
        ) : null}
      </FeedbackCard>
      <FeedbackCard
        key={`incorrect-${partId}`}
        title="Feedback for incorrect answers"
        feedback={incorrectResponse.feedback}
        update={(_id, content) => updateFeedback(incorrectResponse.id, content as RichText)}
        placeholder="Enter catch-all feedback for incorrect answers"
      >
        {authoringContext.contentBreaksExist ? (
          <ShowPage
            editMode={editMode}
            index={incorrectResponse.showPage}
            onChange={(v) => updateShowPage(incorrectResponse.id, v)}
          />
        ) : null}
      </FeedbackCard>
    </>
  );
};
