import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { FeedbackCard } from 'components/activities/common/responses/FeedbackCard';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { HasParts, RichText } from 'components/activities/types';
import { getCorrectResponse, getIncorrectResponse } from 'data/activities/model/responses';
import { TextDirection } from 'data/content/model/elements/types';
import { EditorType } from 'data/content/resource';
import { ShowPage } from './ShowPage';

interface Props {
  partId: string;
}

export const SimpleFeedback: React.FC<Props> = ({ partId }) => {
  const { model, dispatch, editMode, mode, authoringContext } = useAuthoringElementContext<HasParts>();
  const isInstructorPreview = mode === 'instructor_preview';

  const correctResponse = getCorrectResponse(model, partId);

  const incorrectResponse = getIncorrectResponse(model, partId);

  const updateFeedback = (responseId: string, content: RichText) =>
    dispatch(ResponseActions.editResponseFeedback(responseId, content));

  const updateFeedbackEditor = (responseId: string, editor: EditorType) =>
    dispatch(ResponseActions.editResponseFeedbackEditor(responseId, editor));

  const updateShowPage = (responseId: string, showPage: number | undefined) =>
    dispatch(ResponseActions.editShowPage(responseId, showPage));

  const updateTextDirection = (responseId: string, textDirection: TextDirection) =>
    dispatch(ResponseActions.editResponseFeedbackTextDirection(responseId, textDirection));

  return (
    <>
      <FeedbackCard
        key={`correct-${partId}`}
        title="Feedback for correct answer"
        feedback={correctResponse.feedback}
        updateTextDirection={(textDirection) =>
          updateTextDirection(correctResponse.id, textDirection)
        }
        update={(_id, content) => updateFeedback(correctResponse.id, content as RichText)}
        updateEditor={(editor) => updateFeedbackEditor(correctResponse.id, editor)}
        placeholder="Encourage students or explain why the answer is correct"
        editMode={editMode && !isInstructorPreview}
      >
        {authoringContext.contentBreaksExist ? (
          <ShowPage
            editMode={editMode && !isInstructorPreview}
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
        updateEditor={(editor) => updateFeedbackEditor(incorrectResponse.id, editor)}
        updateTextDirection={(textDirection) =>
          updateTextDirection(incorrectResponse.id, textDirection)
        }
        placeholder="Enter catch-all feedback for incorrect answers"
        editMode={editMode && !isInstructorPreview}
      >
        {authoringContext.contentBreaksExist ? (
          <ShowPage
            editMode={editMode && !isInstructorPreview}
            index={incorrectResponse.showPage}
            onChange={(v) => updateShowPage(incorrectResponse.id, v)}
          />
        ) : null}
      </FeedbackCard>
    </>
  );
};
