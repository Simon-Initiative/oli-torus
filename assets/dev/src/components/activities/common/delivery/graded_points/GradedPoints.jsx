import React from 'react';
export const GradedPoints = ({ icon, attemptState, shouldShow }) => {
    if (!shouldShow) {
        return null;
    }
    return (<div className="text-info font-italic">
      {icon}
      <span>Points: </span>
      <span>{attemptState.score + ' out of ' + attemptState.outOf}</span>
    </div>);
};
//# sourceMappingURL=GradedPoints.jsx.map