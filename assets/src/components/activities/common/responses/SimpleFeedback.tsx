import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import {
  getCorrectResponse,
  getIncorrectResponse,
} from 'components/activities/common/responses/authoring/responseUtils';
import { FeedbackCard } from 'components/activities/common/responses/FeedbackCard';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { HasParts, RichText } from 'components/activities/types';
import { Tooltip } from 'components/misc/Tooltip';
import React from 'react';

// eslint-disable-next-line @typescript-eslint/no-empty-interface
interface Props {}
export const SimpleFeedback: React.FC<Props> = ({ children }) => {
  const { model, dispatch } = useAuthoringElementContext<HasParts>();
  const correctResponse = getCorrectResponse(model);
  const incorrectResponse = getIncorrectResponse(model);
  const update = (id: string, content: RichText) =>
    dispatch(ResponseActions.editResponseFeedback(id, content));
  return (
    <>
      <FeedbackCard
        title="Feedback for correct answer"
        feedback={correctResponse.feedback}
        update={(id, content) => update(correctResponse.id, content)}
      />
      <FeedbackCard
        title={
          <>
            Feedback for incorrect answers{' '}
            <Tooltip
              title={
                'Shown for all student responses that do not match the correct answer or targeted feedback combinations'
              }
            />
          </>
        }
        feedback={incorrectResponse.feedback}
        update={(id, content) => update(incorrectResponse.id, content)}
      />
      {children}
    </>
  );
};
