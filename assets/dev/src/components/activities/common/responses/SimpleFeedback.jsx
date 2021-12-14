import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { FeedbackCard } from 'components/activities/common/responses/FeedbackCard';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { getCorrectResponse, getIncorrectResponse } from 'data/activities/model/responses';
import React from 'react';
export const useSimpleFeedback = (partId) => {
    const { model, dispatch } = useAuthoringElementContext();
    return {
        correctResponse: getCorrectResponse(model, partId),
        incorrectResponse: getIncorrectResponse(model, partId),
        updateFeedback: (responseId, content) => dispatch(ResponseActions.editResponseFeedback(responseId, content)),
    };
};
export const SimpleFeedback = ({ children, partId }) => {
    const { correctResponse, incorrectResponse, updateFeedback } = useSimpleFeedback(partId);
    if (typeof children === 'function') {
        return children({ correctResponse, incorrectResponse, updateFeedback });
    }
    return (<>
      <FeedbackCard title="Feedback for correct answer" feedback={correctResponse.feedback} update={(_id, content) => updateFeedback(correctResponse.id, content)} placeholder="Encourage students or explain why the answer is correct"/>
      <FeedbackCard title="Feedback for incorrect answers" feedback={incorrectResponse.feedback} update={(_id, content) => updateFeedback(incorrectResponse.id, content)} placeholder="Enter catch-all feedback for incorrect answers"/>
    </>);
};
//# sourceMappingURL=SimpleFeedback.jsx.map