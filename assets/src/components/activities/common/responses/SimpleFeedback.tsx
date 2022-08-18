import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { FeedbackCard } from 'components/activities/common/responses/FeedbackCard';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { HasParts, RichText } from 'components/activities/types';
import { getCorrectResponse, getIncorrectResponse } from 'data/activities/model/responses';
import { ShowPage } from './ShowPage';

import React from 'react';
import { valHooks } from 'jquery';

interface Props {
  partId: string;
  children?: (xs: ReturnType<typeof useSimpleFeedback>) => React.ReactElement;
}

export const useSimpleFeedback = (partId: string) => {
  const { model, dispatch, editMode, authoringContext } = useAuthoringElementContext<HasParts>();

  return {
    editMode,
    authoringContext,
    correctResponse: getCorrectResponse(model, partId),
    incorrectResponse: getIncorrectResponse(model, partId),
    updateFeedback: (responseId: string, content: RichText) =>
      dispatch(ResponseActions.editResponseFeedback(responseId, content)),
    updateShowPage: (responseId: string, showPage: number | undefined) =>
      dispatch(ResponseActions.editShowPage(responseId, showPage)),
  };
};

export const SimpleFeedback: React.FC<Props> = ({ children, partId }) => {
  const {
    correctResponse,
    incorrectResponse,
    updateFeedback,
    updateShowPage,
    editMode,
    authoringContext,
  } = useSimpleFeedback(partId);

  if (typeof children === 'function') {
    return children({
      correctResponse,
      incorrectResponse,
      updateFeedback,
      updateShowPage,
      editMode,
      authoringContext,
    });
  }

  return (
    <>
      <FeedbackCard
        title="Feedback for correct answer"
        feedback={correctResponse.feedback}
        update={(_id, content) => updateFeedback(correctResponse.id, content as RichText)}
        placeholder="Encourage students or explain why the answer is correct"
      />
      {authoringContext.contentBreaksExist ? (
        <ShowPage
          editMode={editMode}
          index={correctResponse.showPage}
          onChange={(v) => updateShowPage(correctResponse.id, v)}
        />
      ) : null}
      <FeedbackCard
        title="Feedback for incorrect answers"
        feedback={incorrectResponse.feedback}
        update={(_id, content) => updateFeedback(incorrectResponse.id, content as RichText)}
        placeholder="Enter catch-all feedback for incorrect answers"
      />
      {authoringContext.contentBreaksExist ? (
        <ShowPage
          editMode={editMode}
          index={incorrectResponse.showPage}
          onChange={(v) => updateShowPage(incorrectResponse.id, v)}
        />
      ) : null}
    </>
  );
};
