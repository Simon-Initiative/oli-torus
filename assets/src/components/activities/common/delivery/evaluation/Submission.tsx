import { ActivityState } from 'components/activities/types';
import React from 'react';

interface Props {
  attemptState: ActivityState;
}
export const Submission: React.FC<Props> = ({ attemptState }) => {
  if (attemptState.dateEvaluated === null && attemptState.dateSubmitted !== null) {
    return <p>Your attempt has been submitted for instructor grading</p>;
  } else {
    return null;
  }
};
