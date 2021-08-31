import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { assertNever, valueOr } from 'utils/common';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDeliveryConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submit_button/SubmitButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { Provider, useDispatch, useSelector } from 'react-redux';
import {
  ActivityDeliveryState,
  initializeState,
  isEvaluated,
  activityDeliverySlice,
  resetAction,
} from 'data/activities/DeliveryState';
import { configureStore } from 'state/store';
import { safelySelectInput } from 'data/activities/utils';
import { TextInput } from 'components/activities/common/delivery/short_answer/TextInput';
import { TextareaInput } from 'components/activities/common/delivery/short_answer/TextareaInput';
import { NumericInput } from 'components/activities/common/delivery/short_answer/NumericInput';
import {
  DeliveryElement,
  DeliveryElementProps,
  DeliveryElementProvider,
  useDeliveryElementContext,
} from 'components/activities/DeliveryElement';
import { Manifest } from 'components/activities/types';
import { InputType, ShortAnswerModelSchema } from 'components/activities/short_answer/schema';

type InputProps = {
  input: string;
  onChange: (input: any) => void;
  inputType: InputType;
  isEvaluated: boolean;
};

const Input = (props: InputProps) => {
  const shared = {
    onChange: (e: React.ChangeEvent<any>) => props.onChange(e.target.value),
    value: valueOr(props.input, ''),
    disabled: props.isEvaluated,
  };

  switch (props.inputType) {
    case 'numeric':
      return <NumericInput {...shared} />;
    case 'text':
      return <TextInput {...shared} />;
    case 'textarea':
      return <TextareaInput {...shared} />;
    default:
      assertNever(props.inputType);
  }
};

export const ShortAnswerComponent: React.FC = () => {
  const {
    model,
    state: activityState,
    onSaveActivity,
    onResetActivity,
  } = useDeliveryElementContext<ShortAnswerModelSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);

  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(
      initializeState(
        activityState,
        // Short answers only have one input, but the selection is modeled
        // as an array just to make it consistent with the other activity types
        safelySelectInput(activityState).caseOf({
          just: (input) => [input],
          nothing: () => [''],
        }),
      ),
    );
  }, []);

  // First render initializes state
  if (!uiState.attemptState) {
    return null;
  }

  const onInputChange = (input: string) => {
    dispatch(activityDeliverySlice.actions.setSelection([input]));

    onSaveActivity(uiState.attemptState.attemptGuid, [
      { attemptGuid: uiState.attemptState.parts[0].attemptGuid, response: { input } },
    ]);
  };

  return (
    <div className="activity cata-activity">
      <div className="activity-content">
        <StemDeliveryConnected />
        <GradedPointsConnected />

        <Input
          inputType={model.inputType}
          // Short answers only have one selection, but are modeled as an array.
          // Select the first element.
          input={uiState.selection[0]}
          isEvaluated={isEvaluated(uiState)}
          onChange={onInputChange}
        />

        <ResetButtonConnected onReset={() => dispatch(resetAction(onResetActivity, ['']))} />
        <SubmitButtonConnected />
        <HintsDeliveryConnected />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class ShortAnswerDelivery extends DeliveryElement<ShortAnswerModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<ShortAnswerModelSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <ShortAnswerComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.delivery.element, ShortAnswerDelivery);
