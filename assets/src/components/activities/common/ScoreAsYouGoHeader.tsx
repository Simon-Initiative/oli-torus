import React from 'react';
import { useSelector } from 'react-redux';
import { ActivityDeliveryState } from 'data/activities/DeliveryState';

interface Props {}
export const ScoreAsYouGoHeader: React.FC<Props> = ({}) => {
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const { attemptState } = uiState;

  const attempts =
    uiState.activityContext.maxAttempts > 0
      ? `ATTEMPTS ${attemptState.attemptNumber} / ${uiState.activityContext.maxAttempts}`
      : `ATTEMPTS ${attemptState.attemptNumber} of Unlimited`;

  const attemptsOrEmpty =
    !uiState.activityContext.batchScoring && uiState.activityContext.graded ? (
      <div className="text-[#757682] font-open-sans text-[14px] font-bold leading-[150%] tracking-[-0.14px]">
        {attempts}
      </div>
    ) : (
      <div></div>
    );

  return (
    <div className="mt-3 flex justify-between">
      <div>{`Question #${uiState.activityContext.ordinal}`}</div>

      {attemptsOrEmpty}
    </div>
  );
};
