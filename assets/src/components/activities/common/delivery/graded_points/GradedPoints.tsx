import { ActivityState } from 'components/activities/types';
import React from 'react';
interface Props {
  icon: React.ReactNode;
  attemptState: ActivityState;
  shouldShow: boolean;
}
export const GradedPoints: React.FC<Props> = ({ icon, attemptState, shouldShow }) => {
  if (!shouldShow) {
    return null;
  }
  return (
    <div key="correct" className="text-info font-italic">
      {icon}
      <span>Points: </span>
      <span>{attemptState.score + ' out of ' + attemptState.outOf}</span>
    </div>
  );
};
