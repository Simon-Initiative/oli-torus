import React from 'react';
import { useSelector } from 'react-redux';
import { ActivityDeliveryState, isEvaluated } from 'data/activities/DeliveryState';
import { ScoreAsYouGoIcon } from './utils';

interface Props {
  onSubmit: () => void;
  onReset: () => void;
}

function buildConfirmMessage(uiState: ActivityDeliveryState): string {
  const { activityContext } = uiState;

  let scoringDesc = 'average';
  switch (activityContext.scoringStrategyId) {
    case 1:
      scoringDesc = 'average';
      break;
    case 2:
      scoringDesc = 'best';
      break;
    case 3:
      scoringDesc = 'most recent';
      break;
  }

  return `<p>Are you sure you want to reset <strong>Question #${activityContext.ordinal}</strong>?
  If you choose to reset this question, <strong>a new question may be generated</strong>.
  Your overall score on this question will be the <strong>${scoringDesc} of all attempts</strong> of all your attempts. </p>
  <p class="mt-3">If you do not answer the question after resetting, your score could be affected</p>
  `;
}

export const ScoreAsYouGoSubmitReset: React.FC<Props> = ({
  onSubmit,
  onReset,
}) => {
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const { attemptState } = uiState;

  if (uiState.activityContext.graded) {

    if (isEvaluated(uiState)) {

      if (!uiState.activityContext.batchScoring) {

        return (
          <div className="mt-3 flex justify-between">
            <button
              onClick={() => {
                window.OLI.confirmAction("Reset Confirmation", buildConfirmMessage(uiState), () => onReset(), () => {}, "Reset");
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

      }

    } else if (!uiState.activityContext.batchScoring || uiState.activityContext.oneAtATime) {

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
