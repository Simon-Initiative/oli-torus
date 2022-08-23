import { ActivityState } from 'components/activities/types';
import React from 'react';

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
    return <p>Your attempt has been submitted for instructor grading</p>;
  } else {
    return null;
  }
};
