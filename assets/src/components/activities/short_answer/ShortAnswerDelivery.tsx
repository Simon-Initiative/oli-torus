import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import {
  DeliveryElement,
  DeliveryElementProps,
  DeliveryElementProvider,
  useDeliveryElementContext,
} from '../DeliveryElement';
import { InputType, ShortAnswerModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { valueOr } from 'utils/common';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDeliveryConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/gradedPoints/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/resetButton/ResetButtonConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submitButton/SubmitButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { Provider, useDispatch, useSelector } from 'react-redux';
import {
  ActivityDeliveryState,
  initializeState,
  isEvaluated,
  activityDeliverySlice,
  resetAction,
} from 'data/content/activities/DeliveryState';
import { configureStore } from 'state/store';

type InputProps = {
  input: string;
  onChange: (input: any) => void;
  inputType: InputType;
  isEvaluated: boolean;
};

const Input = (props: InputProps) => {
  const input = valueOr(props.input, '');

  if (props.inputType === 'numeric') {
    return (
      <input
        type="number"
        aria-label="answer submission textbox"
        className="form-control"
        onChange={(e: any) => props.onChange(e.target.value)}
        value={input}
        disabled={props.isEvaluated}
      />
    );
  }
  if (props.inputType === 'text') {
    return (
      <input
        type="text"
        aria-label="answer submission textbox"
        className="form-control"
        onChange={(e: any) => props.onChange(e.target.value)}
        value={input}
        disabled={props.isEvaluated}
      />
    );
  }
  return (
    <textarea
      aria-label="answer submission textbox"
      rows={5}
      cols={80}
      className="form-control"
      onChange={(e: any) => props.onChange(e.target.value)}
      value={input}
      disabled={props.isEvaluated}
    ></textarea>
  );
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
    dispatch(initializeState(activityState, valueOr(uiState.attemptState?.parts[0].response, '')));
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
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, ShortAnswerDelivery);
