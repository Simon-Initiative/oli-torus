import { HintsDelivery } from 'components/activities/common/hints/delivery/HintsDelivery';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { isEvaluated, requestHint } from 'data/activities/DeliveryState';
import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
export const HintsDeliveryConnected = (props) => {
    var _a, _b;
    const { onRequestHint, graded, writerContext } = useDeliveryElementContext();
    const uiState = useSelector((state) => state);
    const dispatch = useDispatch();
    return (<HintsDelivery shouldShow={(typeof props.shouldShow === 'undefined' || props.shouldShow) &&
            !isEvaluated(uiState) &&
            !graded} onClick={() => dispatch(requestHint(props.partId, onRequestHint))} hints={((_a = uiState.partState[props.partId]) === null || _a === void 0 ? void 0 : _a.hintsShown) || []} hasMoreHints={((_b = uiState.partState[props.partId]) === null || _b === void 0 ? void 0 : _b.hasMoreHints) || false} isEvaluated={isEvaluated(uiState)} context={writerContext}/>);
};
//# sourceMappingURL=HintsDeliveryConnected.jsx.map