import { SubmitButton } from 'components/activities/common/delivery/submit_button/SubmitButton';
import { useDeliveryElementContext } from 'components/activities/DeliveryElement';
import { isEvaluated, submit } from 'data/activities/DeliveryState';
import React from 'react';
import { useDispatch, useSelector } from 'react-redux';
export const SubmitButtonConnected = ({ disabled }) => {
    const { graded, onSubmitActivity } = useDeliveryElementContext();
    const uiState = useSelector((state) => state);
    const dispatch = useDispatch();
    return (<SubmitButton shouldShow={!isEvaluated(uiState) && !graded} disabled={disabled === undefined
            ? Object.values(uiState.partState)
                .map((partState) => partState.studentInput)
                .every((input) => input.length === 0)
            : disabled} onClick={() => dispatch(submit(onSubmitActivity))}/>);
};
//# sourceMappingURL=SubmitButtonConnected.jsx.map