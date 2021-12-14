import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { assertNever, valueOr } from 'utils/common';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDelivery';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submit_button/SubmitButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { initializeState, isEvaluated, activityDeliverySlice, resetAction, } from 'data/activities/DeliveryState';
import { configureStore } from 'state/store';
import { safelySelectStringInputs } from 'data/activities/utils';
import { TextInput } from 'components/activities/common/delivery/inputs/TextInput';
import { TextareaInput } from 'components/activities/common/delivery/inputs/TextareaInput';
import { NumericInput } from 'components/activities/common/delivery/inputs/NumericInput';
import { DeliveryElement, DeliveryElementProvider, useDeliveryElementContext, } from 'components/activities/DeliveryElement';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { Maybe } from 'tsmonad';
const Input = (props) => {
    const shared = {
        onChange: (e) => props.onChange(e.target.value),
        value: valueOr(props.input, ''),
        disabled: props.isEvaluated,
    };
    switch (props.inputType) {
        case 'numeric':
            return <NumericInput {...shared}/>;
        case 'text':
            return <TextInput {...shared}/>;
        case 'textarea':
            return <TextareaInput {...shared}/>;
        default:
            assertNever(props.inputType);
    }
};
export const ShortAnswerComponent = () => {
    var _a;
    const { model, state: activityState, onSaveActivity, onResetActivity, } = useDeliveryElementContext();
    const uiState = useSelector((state) => state);
    const dispatch = useDispatch();
    useEffect(() => {
        dispatch(initializeState(activityState, 
        // Short answers only have one input, but the selection is modeled
        // as an array just to make it consistent with the other activity types
        safelySelectStringInputs(activityState).caseOf({
            just: (input) => input,
            nothing: () => ({
                [DEFAULT_PART_ID]: [''],
            }),
        })));
    }, []);
    // First render initializes state
    if (!uiState.partState) {
        return null;
    }
    const onInputChange = (input) => {
        dispatch(activityDeliverySlice.actions.setStudentInputForPart({
            partId: DEFAULT_PART_ID,
            studentInput: [input],
        }));
        onSaveActivity(uiState.attemptState.attemptGuid, [
            { attemptGuid: uiState.attemptState.parts[0].attemptGuid, response: { input } },
        ]);
    };
    return (<div className="activity cata-activity">
      <div className="activity-content">
        <StemDeliveryConnected />
        <GradedPointsConnected />

        <Input inputType={model.inputType} 
    // Short answers only have one selection, but are modeled as an array.
    // Select the first element.
    input={Maybe.maybe((_a = uiState.partState[DEFAULT_PART_ID]) === null || _a === void 0 ? void 0 : _a.studentInput).valueOr([''])[0]} isEvaluated={isEvaluated(uiState)} onChange={onInputChange}/>

        <ResetButtonConnected onReset={() => dispatch(resetAction(onResetActivity, { [DEFAULT_PART_ID]: [''] }))}/>
        <SubmitButtonConnected />
        <HintsDeliveryConnected partId={DEFAULT_PART_ID}/>
        <EvaluationConnected />
      </div>
    </div>);
};
// Defines the web component, a simple wrapper over our React component above
export class ShortAnswerDelivery extends DeliveryElement {
    render(mountPoint, props) {
        const store = configureStore({}, activityDeliverySlice.reducer);
        ReactDOM.render(<Provider store={store}>
        <DeliveryElementProvider {...props}>
          <ShortAnswerComponent />
        </DeliveryElementProvider>
      </Provider>, mountPoint);
    }
}
// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json');
window.customElements.define(manifest.delivery.element, ShortAnswerDelivery);
//# sourceMappingURL=ShortAnswerDelivery.jsx.map