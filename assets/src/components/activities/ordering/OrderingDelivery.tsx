import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import {
  DeliveryElement,
  DeliveryElementProps,
  DeliveryElementProvider,
  useDeliveryElementContext,
} from '../DeliveryElement';
import { OrderingSchema } from './schema';
import * as ActivityTypes from '../types';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import {
  ActivityDeliveryState,
  initializeState,
  activityDeliverySlice,
  resetAction,
} from 'data/content/activities/DeliveryState';
import { GradedPointsConnected } from 'components/activities/common/delivery/gradedPoints/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/resetButton/ResetButtonConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submitButton/SubmitButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDeliveryConnected';
import { getChoice } from 'components/activities/common/choices/authoring/choiceUtils';
import { ResponseChoices } from 'components/activities/ordering/sections/ResponseChoices';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { initialSelection, selectionToInput } from 'data/content/activities/utils';

export const OrderingComponent: React.FC = () => {
  const {
    model,
    state: activityState,
    onResetActivity,
    onSaveActivity,
  } = useDeliveryElementContext<OrderingSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  const onSelectionChange = (selection: ActivityTypes.ChoiceId[]) => {
    dispatch(activityDeliverySlice.actions.setSelection(selection));

    onSaveActivity(uiState.attemptState.attemptGuid, [
      {
        attemptGuid: uiState.attemptState.parts[0].attemptGuid,
        response: { input: selectionToInput(selection) },
      },
    ]);
  };

  useEffect(() => {
    dispatch(
      initializeState(
        activityState,
        initialSelection(
          activityState,
          model.choices.map((c) => c.id),
        ),
      ),
    );

    // Ensure when the initial state is null that we set the state to match
    // the initial choice ordering.  This allows submissions without student interaction
    // to be evaluated correctly.
    setTimeout(() => {
      if (activityState.parts[0].response === null) {
        const selection = model.choices.map((choice) => choice.id);
        const input = selectionToInput(selection);
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
  if (!uiState.selection) {
    return null;
  }

  return (
    <div className="activity ordering-activity">
      <div className="activity-content">
        <StemDeliveryConnected />
        <GradedPointsConnected />
        <ResponseChoices
          choices={uiState.selection.map((id) => getChoice(model, id))}
          setChoices={(choices) => onSelectionChange(choices.map((c) => c.id))}
        />
        <ResetButtonConnected
          onReset={() => {
            dispatch(
              resetAction(
                onResetActivity,
                model.choices.map((choice) => choice.id),
              ),
            );
            dispatch(
              activityDeliverySlice.actions.setSelection(model.choices.map((choice) => choice.id)),
            );
          }}
        />
        <SubmitButtonConnected />
        <HintsDeliveryConnected />
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
