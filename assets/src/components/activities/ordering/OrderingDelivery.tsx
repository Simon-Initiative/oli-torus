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
import { Maybe } from 'tsmonad';
import { orderingV1toV2 } from 'components/activities/ordering/transformations/v2';

export const OrderingComponent: React.FC = () => {
  const {
    model,
    state: activityState,
    onResetActivity,
  } = useDeliveryElementContext<OrderingSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(
      initializeState(
        activityState,
        model.choices.map((choice) => choice.id),
      ),
    );
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
          setChoices={(choices) =>
            dispatch(activityDeliverySlice.actions.setSelection(choices.map((c) => c.id)))
          }
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
  migrateModelVersion(model: any): OrderingSchema {
    return Maybe.maybe(model.authoring.version).caseOf({
      just: (v2) => model,
      nothing: () => orderingV1toV2(model),
    });
  }

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
