import { CheckAllThatApplyModelSchema } from 'components/activities/check_all_that_apply/schema';
import { Checkbox } from 'components/misc/icons/checkbox/Checkbox';
import { ActivityState, ChoiceId, Manifest } from 'components/activities/types';
import { isCorrect } from 'data/content/activities/activityUtils';
import {
  ActivityDeliveryState,
  AppThunk,
  initializeState,
  isEvaluated,
  selectChoice,
  activityDeliverySlice,
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

export const store = configureStore({}, activityDeliverySlice.reducer);
const initialize =
  (model: CheckAllThatApplyModelSchema, state: ActivityState): AppThunk =>
  async (dispatch, getState) => {
    dispatch(initializeState(state));
    dispatch(
      slice.actions.setSelectedChoices(
        state.parts[0].response === null
          ? []
          : (state.parts[0].response.input as string)
              .split(' ')
              .reduce((ids, id) => ids.concat([id]), [] as ChoiceId[]),
      ),
    );
  };

export const CheckAllThatApplyComponent: React.FC = () => {
  const {
    model,
    state: activityState,
    onSaveActivity,
  } = useDeliveryElementContext<CheckAllThatApplyModelSchema>();
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
    <div className={`activity cata-activity ${isEvaluated(uiState) ? 'evaluated' : ''}`}>
      <div className="activity-content">
        <StemDeliveryConnected />
        <GradedPointsConnected />
        <ChoicesDeliveryConnected
          unselectedIcon={<Checkbox.Unchecked disabled={isEvaluated(uiState)} />}
          selectedIcon={
            !isEvaluated(uiState) ? (
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
