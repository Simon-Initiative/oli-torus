import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submit_button/SubmitButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDelivery';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';
import { ResponseChoices } from 'components/activities/ordering/sections/ResponseChoices';
import {
  activityDeliverySlice,
  ActivityDeliveryState,
  initializeState,
  isEvaluated,
  isSubmitted,
  listenForParentSurveySubmit,
  listenForParentSurveyReset,
  resetAction,
  StudentInput,
} from 'data/activities/DeliveryState';
import { Choices } from 'data/activities/model/choices';
import { initialPartInputs, studentInputToString } from 'data/activities/utils';
import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import { Maybe } from 'tsmonad';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import * as ActivityTypes from '../types';
import { OrderingSchema } from './schema';

export const OrderingComponent: React.FC = () => {
  const {
    model,
    context,
    state: activityState,
    onSubmitActivity,
    onResetActivity,
    onSaveActivity,
  } = useDeliveryElementContext<OrderingSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();
  const { surveyId, sectionSlug } = context;
  const onSelectionChange = (studentInput: ActivityTypes.ChoiceId[]) => {
    dispatch(
      activityDeliverySlice.actions.setStudentInputForPart({
        partId: DEFAULT_PART_ID,
        studentInput,
      }),
    );

    onSaveActivity(uiState.attemptState.attemptGuid, [
      {
        attemptGuid: uiState.attemptState.parts[0].attemptGuid,
        response: { input: studentInputToString(studentInput) },
      },
    ]);
  };

  const defaultPartInputs = {
    [DEFAULT_PART_ID]: model.choices.map((choice) => choice.id),
  };

  useEffect(() => {
    listenForParentSurveySubmit(surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(surveyId, dispatch, onResetActivity, defaultPartInputs);

    dispatch(
      initializeState(
        activityState,
        initialPartInputs(activityState, {
          [DEFAULT_PART_ID]: model.choices.map((c) => c.id),
        }),
        model,
        sectionSlug,
      ),
    );

    // Ensure when the initial state is null that we set the state to match
    // the initial choice ordering.  This allows submissions without student interaction
    // to be evaluated correctly.
    setTimeout(() => {
      if (activityState.parts[0].response === null) {
        const selection = (uiState.model as OrderingSchema).choices.map((choice) => choice.id);
        const input = studentInputToString(selection);
        onSaveActivity(activityState.attemptGuid, [
          {
            attemptGuid: activityState.parts[0].attemptGuid,
            response: { input },
          },
        ]);
      }
    }, 0);
  }, []);

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  return (
    <div className="activity ordering-activity">
      <div className="activity-content">
        <StemDeliveryConnected />
        <GradedPointsConnected />
        <ResponseChoices
          choices={Maybe.maybe(uiState.partState[DEFAULT_PART_ID]?.studentInput)
            .valueOr<StudentInput>([])
            .map((id) => Choices.getOne(uiState.model as OrderingSchema, id))}
          setChoices={(choices) => onSelectionChange(choices.map((c) => c.id))}
          disabled={isEvaluated(uiState) || isSubmitted(uiState)}
        />
        <ResetButtonConnected
          onReset={() => dispatch(resetAction(onResetActivity, defaultPartInputs))}
        />
        <SubmitButtonConnected />
        <HintsDeliveryConnected partId={DEFAULT_PART_ID} />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class OrderingDelivery extends DeliveryElement<OrderingSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<OrderingSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <OrderingComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, OrderingDelivery);
