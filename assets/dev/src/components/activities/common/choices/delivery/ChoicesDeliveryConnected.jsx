import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { isEvaluated } from 'data/activities/DeliveryState';
import React from 'react';
import { useSelector } from 'react-redux';
export const ChoicesDeliveryConnected = ({ onSelect, unselectedIcon, selectedIcon, partId, }) => {
    var _a;
    const { model, writerContext } = useDeliveryElementContext();
    const uiState = useSelector((state) => state);
    return (<ChoicesDelivery unselectedIcon={unselectedIcon} selectedIcon={selectedIcon} choices={model.choices} selected={((_a = uiState.partState[partId]) === null || _a === void 0 ? void 0 : _a.studentInput) || []} onSelect={onSelect} isEvaluated={isEvaluated(uiState)} context={writerContext}/>);
};
//# sourceMappingURL=ChoicesDeliveryConnected.jsx.map