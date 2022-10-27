import React, { useEffect, useRef } from 'react';
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
  listenForReviewAttemptChange,
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
import { castPartId } from '../common/utils';
import { initializePersistence } from '../common/delivery/persistence';

type InputProps = {
  input: string;
  inputType: InputType;
  isEvaluated: boolean;
  isSubmitted: boolean;
  onChange: (value: string) => void;
  onBlur?: () => void;
};

const Input = (props: InputProps) => {
  const value = valueOr(props.input, '');
  const shared = {
    onChange: (value: string) => props.onChange(value),
    value,
    disabled: props.isEvaluated || props.isSubmitted,
    onBlur: props.onBlur,
    onKeyUp: () => {},
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
  const deferredSave = useRef(initializePersistence());

  useEffect(() => {
    listenForParentSurveySubmit(surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(surveyId, dispatch, onResetActivity, {
      [castPartId(activityState.parts[0].partId)]: [''],
    });
    listenForReviewAttemptChange(model, activityState.activityId as number, dispatch, context);

    dispatch(
      initializeState(
        activityState,
        // Short answers only have one input, but the selection is modeled
        // as an array just to make it consistent with the other activity types
        safelySelectStringInputs(activityState).caseOf({
          just: (input) => input,
          nothing: () => ({
            [castPartId(activityState.parts[0].partId)]: [''],
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
        partId: castPartId(activityState.parts[0].partId),
        studentInput: [input],
      }),
    );

    deferredSave.current.save(() =>
      onSaveActivity(uiState.attemptState.attemptGuid, [
        { attemptGuid: uiState.attemptState.parts[0].attemptGuid, response: { input } },
      ]),
    );
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
            Maybe.maybe(
              uiState.partState[castPartId(activityState.parts[0].partId)]?.studentInput,
            ).valueOr([''])[0]
          }
          isEvaluated={isEvaluated(uiState)}
          isSubmitted={isSubmitted(uiState)}
          onChange={onInputChange}
          onBlur={() => deferredSave.current.flushPendingChanges(false)}
        />

        <ResetButtonConnected
          onReset={() =>
            dispatch(
              resetAction(onResetActivity, { [castPartId(activityState.parts[0].partId)]: [''] }),
            )
          }
        />
        <SubmitButtonConnected />
        <HintsDeliveryConnected partId={castPartId(activityState.parts[0].partId)} />
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
