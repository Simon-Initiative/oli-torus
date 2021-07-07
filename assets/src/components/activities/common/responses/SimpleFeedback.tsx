import { FeedbackCard } from 'components/activities/common/responses/FeedbackCard';
import { Response, RichText } from 'components/activities/types';
import { Tooltip } from 'components/misc/Tooltip';
import { ID } from 'data/content/model';
import React from 'react';

interface Props {
  correctResponse: Response;
  incorrectResponse: Response;
  update: (responseId: ID, content: RichText) => void;
}
export const SimpleFeedback: React.FC<Props> = ({
  correctResponse,
  incorrectResponse,
  update,
  children,
}) => {
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
