import React from 'react';
import { ActivityState } from 'components/activities/types';

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
    <div className="text-info font-italic">
      {icon}
      <span>Points: </span>
      <span>{attemptState.score + ' out of ' + attemptState.outOf}</span>
    </div>
  );
};
