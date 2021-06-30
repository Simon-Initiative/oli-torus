import { HintsDelivery } from 'components/activities/common/hints/delivery/HintsDelivery';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { HasHints } from 'components/activities/types';
import {
  ActivityDeliveryState,
  isEvaluated,
  requestHint,
} from 'data/content/activities/DeliveryState';
import React from 'react';
import { useDispatch, useSelector } from 'react-redux';

export const HintsDeliveryConnected: React.FC = () => {
  const { onRequestHint, graded, writerContext } = useDeliveryElementContext<HasHints>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();
  return (
    <HintsDelivery
      shouldShow={!isEvaluated(uiState) && !graded}
      onClick={() => dispatch(requestHint(onRequestHint))}
      hints={uiState.hints}
      hasMoreHints={uiState.hasMoreHints}
      isEvaluated={isEvaluated(uiState)}
      context={writerContext}
    />
  );
};
