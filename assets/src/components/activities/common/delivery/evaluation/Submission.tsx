import React from 'react';
import { ActivityState } from 'components/activities/types';

interface Props {
  attemptState: ActivityState;
  surveyId: string | null;
}
export const Submission: React.FC<Props> = ({ attemptState, surveyId }) => {
  if (
    attemptState.dateEvaluated === null &&
    attemptState.dateSubmitted !== null &&
    surveyId === null
  ) {
    return <p>Your response has been received</p>;
  } else {
    return null;
  }
};
