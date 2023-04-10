import { useDeliveryElementContext } from 'components/activities/DeliveryElementProvider';
import { HintsDelivery } from 'components/activities/common/hints/delivery/HintsDelivery';

import {
  ActivityDeliveryState,
  isEvaluated,
  isSubmitted,
  requestHint,
} from 'data/activities/DeliveryState';
import React from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { HintsDeliveryConnected } from '../common/hints/delivery/HintsDeliveryConnected';

export type FocusedHintsProps = {
  focusedPart: string | null;
};

export const FocusedHints: React.FC<FocusedHintsProps> = (props: FocusedHintsProps) => {
  const { focusedPart } = props;
  const { context } = useDeliveryElementContext();
  const { graded } = context;
  const uiState = useSelector((state: ActivityDeliveryState) => state);

  // If not item is selected, or this is within a survey, or if it is graded but not in review mode, do not show feedback
  if (focusedPart === null || graded) {
    return null;
  }

  const part = uiState.attemptState.parts.find((ps) => ps.partId === focusedPart);

  return part !== undefined ? (
    <HintsDeliveryConnected
      partId={String(part.partId)}

      // shouldShow={true}
      // onClick={() => dispatch(requestHint(focusedPart, onRequestHint))}
      // hints={uiState.partState[focusedPart]?.hintsShown || []}
      // hasMoreHints={uiState.partState[focusedPart]?.hasMoreHints || false}
      // // @ts-ignore
      // isEvaluated={isEvaluated(uiState)}
      // isSubmitted={isSubmitted(uiState)}
      // context={writerContext}
    />
  ) : null;
};
