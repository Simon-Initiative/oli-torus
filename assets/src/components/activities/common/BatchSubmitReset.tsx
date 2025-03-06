import React from 'react';
import { useSelector } from 'react-redux';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { ActivityModelSchema, ChoiceId, HasChoices, PartId } from 'components/activities/types';
import { ActivityDeliveryState, isEvaluated } from 'data/activities/DeliveryState';

import { modalActions } from 'actions/modal';

interface Props {
  onSubmit: () => void;
  onReset: () => void;
}
export const BatchSubmitReset: React.FC<Props> = ({
  onSubmit,
  onReset,
}) => {
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const { attemptState } = uiState;

  const dismiss = () => window.oliDispatch(modalActions.dismiss());
  const display = (c: any) => window.oliDispatch(modalActions.display(c));

  if (!uiState.activityContext.batchScoring && uiState.activityContext.graded) {
    if (isEvaluated(uiState)) {
      return (
        <div className="mt-3 flex justify-between">
          <button
            onClick={() => {
              display(<p>HERE IT IS</p>);
            }}
          >
            <span className="text-red-700"><i className="fa-solid fa-rotate-right mr-2"></i>Reset Question</span>
          </button>
          <div className="text-green-500 dark:text-green-300">
            <span>Points: </span>
            <span>{attemptState.score?.toFixed(2) + ' / ' + attemptState.outOf}</span>
          </div>

        </div>
      );
    } else {
      return (
        <div className="flex justify-center">
          <button
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
