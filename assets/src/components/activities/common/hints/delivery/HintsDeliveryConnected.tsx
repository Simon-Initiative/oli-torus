import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { HintsDelivery } from 'components/activities/common/hints/delivery/HintsDelivery';
import { HasHints, PartId } from 'components/activities/types';
import {
  ActivityDeliveryState,
  PartInputs,
  isEvaluated,
  isSubmitted,
  requestHint,
  resetAndRequestHintAction,
} from 'data/activities/DeliveryState';
import { isCorrect } from '../../../../../data/activities/utils';

interface Props {
  partId: PartId;
  shouldShow?: boolean;
  resetPartInputs?: PartInputs; // If we need to reset, what part inputs should we default to?
}

const shouldShow = (
  uiState: ActivityDeliveryState,
  graded: boolean,
  surveyId: string | null,
  shouldShow?: boolean,
  allowHints?: boolean,
) => {
  if (!graded) return true;
  if (surveyId !== null) return false;
  if (shouldShow) return true;

  return !isEvaluated(uiState) && !isSubmitted(uiState) && allowHints;
};

const isRequestHintDisabled = (
  uiState: ActivityDeliveryState,
  hasMoreHints: boolean,
  correct: boolean,
) => {
  if (!hasMoreHints) return false;
  if (isEvaluated(uiState)) return true;
  if (!correct) return false;

  return isEvaluated(uiState) || isSubmitted(uiState);
};

/*
    Rules for requesting hints.

    1. You can request hints before answering
    2. You can see hints on incorrect
    3. You can request additional hints on incorrect, but that implicitly resets (I'd suggest that for both question types).
    4. Hints are always visible
    5. Once you see a hint, it remains revealed until you get it correct.
*/
export const HintsDeliveryConnected: React.FC<Props> = (props) => {
  const { context, writerContext, onRequestHint, onResetActivity } =
    useDeliveryElementContext<HasHints>();
  const { graded, surveyId, allowHints } = context;
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  const correct = isCorrect(uiState.attemptState);
  const shouldShowHint = shouldShow(uiState, graded, surveyId, props.shouldShow, allowHints);
  const hasMoreHints = uiState.partState[props.partId]?.hasMoreHints || false;
  const requestHintDisabled = isRequestHintDisabled(uiState, hasMoreHints, correct);

  const onHint = () => {
    if (isEvaluated(uiState)) {
      // We continue to display hints on incorrect answers, so we need to reset before getting the next one.
      dispatch(
        resetAndRequestHintAction(
          props.partId,
          onRequestHint,
          onResetActivity,
          props.resetPartInputs,
        ),
      );
    } else {
      dispatch(requestHint(props.partId, onRequestHint));
    }
  };

  return (
    <div>
      {/* <pre>
        {JSON.stringify(
          {
            hints: uiState.partState[props.partId]?.hintsShown || [],
            correct,
            isEvaluated: isEvaluated(uiState),
            isSubmitted: isSubmitted(uiState),
            shouldShowHint,
            propsShouldShow: props.shouldShow,
            hasMoreHints,
            requestHintDisabled,
            graded,
            surveyId,
          },
          null,
          2,
        )}
      </pre> */}
      <HintsDelivery
        shouldShow={shouldShowHint}
        onClick={onHint}
        hints={uiState.partState[props.partId]?.hintsShown || []}
        hasMoreHints={hasMoreHints}
        context={writerContext}
        requestHintDisabled={requestHintDisabled}
      />
    </div>
  );
};
