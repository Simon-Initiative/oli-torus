import { CheckAllThatApplyModelSchema } from 'components/activities/check_all_that_apply/schema';
import { Checkbox } from 'components/activities/common/icons/Checkbox';
import { Manifest } from 'components/activities/types';
import { isCorrect } from 'data/content/activities/activityUtils';
import {
  ActivityDeliveryState,
  initializeState,
  isEvaluated,
  selectChoice,
  slice,
} from 'data/content/activities/DeliveryState';
import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import {
  DeliveryElement,
  DeliveryElementProps,
  DeliveryElementProvider,
  useDeliveryElementContext,
} from '../DeliveryElement';
import { ResetButtonConnected } from 'components/activities/common/delivery/resetButton/ResetButtonConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submitButton/SubmitButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/gradedPoints/GradedPointsConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDeliveryConnected';
import { ChoicesDeliveryConnected } from 'components/activities/common/choices/delivery/ChoicesDeliveryConnected';

export const store = configureStore({}, slice.reducer);

export const CheckAllThatApplyComponent: React.FC = () => {
  const {
    model,
    state: activityState,
    onSaveActivity,
  } = useDeliveryElementContext<CheckAllThatApplyModelSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(initializeState(model, activityState));
  }, []);

  // First render initializes state
  if (!uiState.selectedChoices) {
    return null;
  }

  const evaluated = isEvaluated(uiState);

  return (
    <div className={`activity cata-activity ${evaluated ? 'evaluated' : ''}`}>
      <div className="activity-content">
        <StemDeliveryConnected />
        <GradedPointsConnected />
        <ChoicesDeliveryConnected
          unselectedIcon={<Checkbox.Unchecked disabled={evaluated} />}
          selectedIcon={
            !evaluated ? (
              <Checkbox.Checked />
            ) : isCorrect(uiState.attemptState) ? (
              <Checkbox.Correct />
            ) : (
              <Checkbox.Incorrect />
            )
          }
          onSelect={(id) => dispatch(selectChoice(id, onSaveActivity, 'multiple'))}
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
export class CheckAllThatApplyDelivery extends DeliveryElement<CheckAllThatApplyModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<CheckAllThatApplyModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <CheckAllThatApplyComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.delivery.element, CheckAllThatApplyDelivery);
