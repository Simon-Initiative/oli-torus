import React from 'react';
import { useSelector } from 'react-redux';
import { ActivityDeliveryState, isEvaluated } from 'data/activities/DeliveryState';

import { modalActions } from 'actions/modal';
import { ScoreAsYouGoIcon } from './utils';

interface Props {
  onSubmit: () => void;
  onReset: () => void;
}
export const ScoreAsYouGoSubmitReset: React.FC<Props> = ({
  onSubmit,
  onReset,
}) => {
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const { attemptState } = uiState;

  if (!uiState.activityContext.batchScoring && uiState.activityContext.graded) {
    if (isEvaluated(uiState)) {
      return (
        <div className="mt-3 flex justify-between">
          <button
            onClick={() => {
              console.log("Resetting question");
              window.OLI.openModal("activityReset");
            }}
          >
            <span className="text-red-700"><i className="fa-solid fa-rotate-right mr-2"></i>Reset Question</span>
          </button>
          <div className="text-green-500 dark:text-green-300">
            <span><ScoreAsYouGoIcon/> Points: </span>
            <span>{attemptState.score?.toFixed(2) + ' / ' + attemptState.outOf}</span>
          </div>

        </div>
      );
    } else {
      return (
        <div className="flex justify-center">
          <button
            disabled={uiState.activityContext.maxAttempts > 0 && attemptState.attemptNumber >= uiState.activityContext.maxAttempts}
            className="btn btn-primary"
            onClick={() => onSubmit()}
          >
            Submit Response
          </button>
        </div>
      );
    }
  }

  return null;
};
