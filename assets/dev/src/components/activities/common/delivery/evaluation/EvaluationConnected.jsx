import { Evaluation } from 'components/activities/common/delivery/evaluation/Evaluation';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { isEvaluated } from 'data/activities/DeliveryState';
import React from 'react';
import { useSelector } from 'react-redux';
export const EvaluationConnected = () => {
    const { graded, mode, writerContext } = useDeliveryElementContext();
    const uiState = useSelector((state) => state);
    return (<Evaluation shouldShow={isEvaluated(uiState) && (!graded || mode === 'review')} attemptState={uiState.attemptState} context={writerContext}/>);
};
//# sourceMappingURL=EvaluationConnected.jsx.map