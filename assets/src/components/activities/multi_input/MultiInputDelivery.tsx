import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import {
  ActivityDeliveryState,
  initializeState,
  setSelection,
  activityDeliverySlice,
  resetAction,
} from 'data/activities/DeliveryState';
import { initialSelection } from 'data/activities/utils';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submit_button/SubmitButtonConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDeliveryConnected';
import {
  DeliveryElement,
  DeliveryElementProps,
  DeliveryElementProvider,
  useDeliveryElementContext,
} from 'components/activities/DeliveryElement';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { Manifest } from 'components/activities/types';
import { InputRef } from 'data/content/model';
import { DropdownInput } from 'components/activities/multi_input/sections/delivery/DropdownInput';
import { toSimpleText } from 'components/editing/utils';
import { TextInput } from 'components/activities/common/delivery/short_answer/TextInput';

/*
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
*/

interface InputRefProps {
  inputRef: HTMLElement;
  model: MultiInputSchema;
}
const InputRef: React.FC<InputRefProps> = (props) => {
  // const shared = {
  //   onChange: (e: React.ChangeEvent<any>) => props.onChange(e.target.value),
  //   value: valueOr(props.input, ''),
  //   disabled: props.isEvaluated,
  // };

  const { type, partId, choiceIds } = props.inputRef.dataset;
  if (type === 'dropdown') {
    return ReactDOM.createPortal(
      <DropdownInput
        onChange={() => {}}
        options={props.model.choices
          .filter((choice) => choiceIds?.split(',').includes(choice.id))
          .map((choice) => ({
            value: choice.id,
            content: toSimpleText({ children: choice.content.model }),
          }))}
      />,
      props.inputRef,
    );
  }
  return ReactDOM.createPortal(<TextInput onChange={() => {}} value="Hey" />, props.inputRef);
};

export const MultiInputComponent: React.FC = () => {
  const {
    state: activityState,
    onSaveActivity,
    onResetActivity,
    model,
  } = useDeliveryElementContext<MultiInputSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  const [inputRefs, setInputRefs] = React.useState<any>([]);

  useEffect(() => {
    dispatch(initializeState(activityState, initialSelection(activityState)));
  }, []);

  useEffect(() => {
    const inputRefs = document.querySelectorAll('span[data-type="input_ref"]');
    console.log('inputRefs', inputRefs);
    setInputRefs([...inputRefs]);
    // inputRefs.forEach((ref) => ReactDOM.createPortal(<input>HEY</input>, ref));
  }, [uiState.selection]);
  // Add hints button to right of each input
  // Find the best way to display a React component for the input refs
  // found when parsing
  // Map choices to ids found in input ref
  // model.inputs.forEach((input) => {
  //   const inputRef = document.querySelector(`#${input.id}`);
  //   if (inputRef) {
  //     ReactDOM.render(<input />, inputRef);
  //   }
  // });

  // First render initializes state
  if (!uiState.selection) {
    return null;
  }

  console.log('selection', uiState.selection);

  return (
    <div className="activity mc-activity">
      <div className="activity-content">
        {inputRefs.map((inputRef: HTMLElement) => (
          <InputRef key={inputRef.id} inputRef={inputRef} model={model} />
        ))}
        <StemDeliveryConnected className="form-inline" />
        <GradedPointsConnected />
        <select
          onChange={(e) => dispatch(setSelection(e.target.value, onSaveActivity, 'single'))}
          className="custom-select"
        >
          {/* {model.choices.map((c) => (
            <option selected={uiState.selection[0] === c.id} key={c.id} value={c.id}>
              {toSimpleText({ children: c.content.model })}
            </option>
          ))} */}
        </select>
        <ResetButtonConnected onReset={() => dispatch(resetAction(onResetActivity, []))} />
        <SubmitButtonConnected disabled={false} />
        <HintsDeliveryConnected />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class MultiInputDelivery extends DeliveryElement<MultiInputSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<MultiInputSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <MultiInputComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.delivery.element, MultiInputDelivery);
