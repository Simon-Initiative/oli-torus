import React from 'react';
import { useSelector } from 'react-redux';
import { ActivityDeliveryState } from 'data/activities/DeliveryState';

interface Props {}
export const ScoreAsYouGoHeader: React.FC<Props> = () => {
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const { attemptState } = uiState;

  return (
    <ScoreAsYouGoHeaderBase
      batchScoring={uiState.activityContext.batchScoring}
      graded={uiState.activityContext.graded}
      ordinal={uiState.activityContext.ordinal}
      maxAttempts={uiState.activityContext.maxAttempts}
      attemptNumber={attemptState.attemptNumber}
    />
  );
};

interface BaseProps {
  batchScoring: boolean;
  graded: boolean;
  ordinal: number;
  maxAttempts: number;
  attemptNumber: number;
}
export const ScoreAsYouGoHeaderBase: React.FC<BaseProps> = ({
  batchScoring,
  graded,
  ordinal,
  attemptNumber,
  maxAttempts,
}) => {
  const attempts =
    maxAttempts > 0
      ? `ATTEMPTS ${attemptNumber} / ${maxAttempts}`
      : `ATTEMPTS ${attemptNumber} of Unlimited`;

  const attemptsOrEmpty =
    !batchScoring && graded ? (
      <div className="text-[#757682] font-open-sans text-[14px] font-bold leading-[150%] tracking-[-0.14px]">
        {attempts}
      </div>
    ) : (
      <div>&nbsp;</div>
    );

  return graded ? (
    <div className="mt-3 flex justify-between">
      <div>{`Question #${ordinal}`}</div>

      {attemptsOrEmpty}
    </div>
  ) : null;
};
