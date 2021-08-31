import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import {
  DeliveryElement,
  DeliveryElementProps,
  DeliveryElementProvider,
  useDeliveryElementContext,
} from '../DeliveryElement';
import { DropdownModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import {
  ActivityDeliveryState,
  initializeState,
  setSelection,
  activityDeliverySlice,
  resetAction,
} from 'data/content/activities/DeliveryState';
import { initialSelection } from 'data/content/activities/utils';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submit_button/SubmitButtonConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDeliveryConnected';
import { toSimpleText } from 'data/content/text';

export const DropdownComponent: React.FC = () => {
  const {
    state: activityState,
    onSaveActivity,
    onResetActivity,
    model,
  } = useDeliveryElementContext<DropdownModelSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(initializeState(activityState, initialSelection(activityState)));
  }, []);

  // First render initializes state
  if (!uiState.selection) {
    return null;
  }

  return (
    <div className="activity mc-activity">
      <div className="activity-content">
        <StemDeliveryConnected />
        <GradedPointsConnected />
        <select
          onChange={(e) => dispatch(setSelection(e.target.value, onSaveActivity, 'single'))}
          className="custom-select"
        >
          {model.choices.map((c) => (
            <option selected={uiState.selection[0] === c.id} key={c.id} value={c.id}>
              {toSimpleText({ children: c.content.model })}
            </option>
          ))}
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
export class DropdownDelivery extends DeliveryElement<DropdownModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<DropdownModelSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <DropdownComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, DropdownDelivery);
