import { HintsDelivery } from 'components/activities/common/hints/delivery/HintsDelivery';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { HasHints, PartId } from 'components/activities/types';
import { ActivityDeliveryState, isEvaluated, requestHint } from 'data/activities/DeliveryState';
import React from 'react';
import { useDispatch, useSelector } from 'react-redux';

interface Props {
  partId: PartId;
  shouldShow?: boolean;
}
export const HintsDeliveryConnected: React.FC<Props> = (props) => {
  const { onRequestHint, graded, writerContext } = useDeliveryElementContext<HasHints>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  return (
    <HintsDelivery
      shouldShow={
        (typeof props.shouldShow === 'undefined' || props.shouldShow) &&
        !isEvaluated(uiState) &&
        !graded
      }
      onClick={() => dispatch(requestHint(props.partId, onRequestHint))}
      hints={uiState.partState[props.partId]?.hintsShown || []}
      hasMoreHints={uiState.partState[props.partId]?.hasMoreHints || false}
      isEvaluated={isEvaluated(uiState)}
      context={writerContext}
    />
  );
};
