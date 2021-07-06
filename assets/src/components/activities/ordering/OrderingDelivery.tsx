import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import {
  DeliveryElement,
  DeliveryElementProps,
  DeliveryElementProvider,
  useDeliveryElementContext,
} from '../DeliveryElement';
import { OrderingModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import {
  ActivityDeliveryState,
  AppThunk,
  initializeState,
  isEvaluated,
  slice,
} from 'data/content/activities/DeliveryState';
import './OrderingDelivery.scss';
import { GradedPointsConnected } from 'components/activities/common/delivery/gradedPoints/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/resetButton/ResetButtonConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submitButton/SubmitButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDeliveryConnected';
import { getChoice } from 'components/activities/common/choices/authoring/choiceUtils';
import { OrderingChoices } from 'components/activities/ordering/sections/OrderingChoices';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';

export const store = configureStore({}, slice.reducer);
const initialize =
  (model: OrderingModelSchema, state: ActivityTypes.ActivityState): AppThunk =>
  async (dispatch, getState) => {
    dispatch(initializeState(state));
    dispatch(slice.actions.setSelectedChoices(model.choices.map((choice) => choice.id)));
  };

export const OrderingComponent: React.FC = () => {
  const { model, state: activityState } = useDeliveryElementContext<OrderingModelSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(initialize(model, activityState));
  }, []);

  // First render initializes state
  if (!uiState.selectedChoices) {
    return null;
  }

  return (
    <div className={`activity ordering-activity ${isEvaluated(uiState) ? 'evaluated' : ''}`}>
      <div className="activity-content">
        <StemDeliveryConnected />
        <GradedPointsConnected />
        <OrderingChoices
          choices={uiState.selectedChoices.map((id) => getChoice(model, id))}
          setChoices={(choices) =>
            dispatch(slice.actions.setSelectedChoices(choices.map((c) => c.id)))
          }
        />
        <ResetButtonConnected />
        <SubmitButtonConnected />
        <HintsDeliveryConnected />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class OrderingDelivery extends DeliveryElement<OrderingModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<OrderingModelSchema>) {
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
