import { GradedPoints } from 'components/activities/common/delivery/graded_points/GradedPoints';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { Checkmark } from 'components/misc/icons/Checkmark';
import { Cross } from 'components/misc/icons/Cross';
import { isCorrect } from 'data/activities/utils';
import React from 'react';
import { useSelector } from 'react-redux';
export const GradedPointsConnected = () => {
    const { graded, mode } = useDeliveryElementContext();
    const uiState = useSelector((state) => state);
    return (<GradedPoints shouldShow={graded && mode === 'review'} icon={isCorrect(uiState.attemptState) ? <Checkmark /> : <Cross />} attemptState={uiState.attemptState}/>);
};
//# sourceMappingURL=GradedPointsConnected.jsx.map