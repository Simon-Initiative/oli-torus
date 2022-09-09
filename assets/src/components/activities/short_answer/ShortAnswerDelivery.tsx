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
import {
  ActivityDeliveryState,
  initializeState,
  isEvaluated,
  isSubmitted,
  activityDeliverySlice,
  resetAction,
  listenForParentSurveySubmit,
  listenForParentSurveyReset,
} from 'data/activities/DeliveryState';
import { configureStore } from 'state/store';
import { safelySelectStringInputs } from 'data/activities/utils';
import { TextInput } from 'components/activities/common/delivery/inputs/TextInput';
import { TextareaInput } from 'components/activities/common/delivery/inputs/TextareaInput';
import { NumericInput } from 'components/activities/common/delivery/inputs/NumericInput';
import { DeliveryElement, DeliveryElementProps } from 'components/activities/DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { Manifest } from 'components/activities/types';
import { InputType, ShortAnswerModelSchema } from 'components/activities/short_answer/schema';
import { Maybe } from 'tsmonad';
import { MathInput } from '../common/delivery/inputs/MathInput';

type InputProps = {
  input: string;
  inputType: InputType;
  isEvaluated: boolean;
  isSubmitted: boolean;
  onChange: (value: string) => void;
};

const Input = (props: InputProps) => {
  const value = valueOr(props.input, '');
  const shared = {
    onChange: (value: string) => props.onChange(value),
    value,
    disabled: props.isEvaluated || props.isSubmitted,
  };

  switch (props.inputType) {
    case 'numeric':
      return <NumericInput {...shared} />;
    case 'text':
      return <TextInput {...shared} />;
    case 'textarea':
      return <TextareaInput {...shared} />;
    case 'math':
      return <MathInput {...shared} onChange={(v) => props.onChange(v)} />;
    default:
      assertNever(props.inputType);
  }
};

export const ShortAnswerComponent: React.FC = () => {
  const {
    model,
    state: activityState,
    context,
    onSubmitActivity,
    onSaveActivity,
    onResetActivity,
  } = useDeliveryElementContext<ShortAnswerModelSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const { surveyId } = context;
  const dispatch = useDispatch();

  useEffect(() => {
    listenForParentSurveySubmit(surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(surveyId, dispatch, onResetActivity, {
      [model.authoring.parts[0].id]: [''],
    });

    dispatch(
      initializeState(
        activityState,
        // Short answers only have one input, but the selection is modeled
        // as an array just to make it consistent with the other activity types
        safelySelectStringInputs(activityState).caseOf({
          just: (input) => input,
          nothing: () => ({
            [model.authoring.parts[0].id]: [''],
          }),
        }),
        model,
        context,
      ),
    );
  }, []);

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  const onInputChange = (input: string) => {
    dispatch(
      activityDeliverySlice.actions.setStudentInputForPart({
        partId: model.authoring.parts[0].id,
        studentInput: [input],
      }),
    );

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
          inputType={(uiState.model as ShortAnswerModelSchema).inputType}
          // Short answers only have one selection, but are modeled as an array.
          // Select the first element.
          input={
            Maybe.maybe(uiState.partState[model.authoring.parts[0].id]?.studentInput).valueOr([
              '',
            ])[0]
          }
          isEvaluated={isEvaluated(uiState)}
          isSubmitted={isSubmitted(uiState)}
          onChange={onInputChange}
        />

        <ResetButtonConnected
          onReset={() =>
            dispatch(resetAction(onResetActivity, { [model.authoring.parts[0].id]: [''] }))
          }
        />
        <SubmitButtonConnected />
        <HintsDeliveryConnected partId={model.authoring.parts[0].id} />
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
