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

  const dismiss = () => window.oliDispatch(modalActions.dismiss());
  const display = (c: any) => window.oliDispatch(modalActions.display(c));

  console.log(uiState.activityContext);

  if (uiState.activityContext.batchScoring && uiState.activityContext.graded) {
    if (isEvaluated(uiState)) {
      return (
        <button
          onClick={() => {
            display(<p>HERE IT IS</p>);
          }}
        >
          <span><i className="fa-solid fa-rotate-right"></i>Reset Question</span>
        </button>
      );
    } else {
      return (
        <button
          className="btn btn-primary flex justify-center"
          onClick={() => onSubmit()}
        >
          Submit Response
        </button>
      );
    }
  }

  return null;
};
