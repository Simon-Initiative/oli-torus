import { FeedbackCard } from 'components/activities/common/feedback/FeedbackCard';
import { Feedback, RichText } from 'components/activities/types';
import { Tooltip } from 'components/misc/Tooltip';
import { ID } from 'data/content/model';
import React from 'react';

interface Props {
  correctFeedback: Feedback;
  incorrectFeedback: Feedback;
  update: (id: ID, content: RichText) => void;
}
export const SimpleFeedback: React.FC<Props> = ({
  correctFeedback,
  incorrectFeedback,
  update,
  children,
}) => {
  return (
    <>
      <FeedbackCard
        title="Feedback for correct answer"
        feedback={correctFeedback}
        update={update}
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
        feedback={incorrectFeedback}
        update={update}
      />
      {children}
    </>
  );
};
