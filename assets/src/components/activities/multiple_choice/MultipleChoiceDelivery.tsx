import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { MCSchema } from './schema';
import * as ActivityTypes from '../types';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import {
  ActivityDeliveryState,
  initializeState,
  setSelection,
  activityDeliverySlice,
  isEvaluated,
  resetAction,
  listenForParentSurveySubmit,
} from 'data/activities/DeliveryState';
import { Radio } from 'components/misc/icons/radio/Radio';
import { initialPartInputs, isCorrect } from 'data/activities/utils';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submit_button/SubmitButtonConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDelivery';
import { ChoicesDeliveryConnected } from 'components/activities/common/choices/delivery/ChoicesDeliveryConnected';
import { DEFAULT_PART_ID } from 'components/activities/common/utils';

export const MultipleChoiceComponent: React.FC = () => {
  const {
    state: activityState,
    surveyId,
    onSubmitActivity,
    onSaveActivity,
    onResetActivity,
  } = useDeliveryElementContext<MCSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  useEffect(() => {
    listenForParentSurveySubmit(surveyId, dispatch, onSubmitActivity);

    dispatch(initializeState(activityState, initialPartInputs(activityState)));
  }, []);

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  return (
    <div className="activity mc-activity">
      <div className="activity-content">
        <StemDeliveryConnected />
        <GradedPointsConnected />
        <ChoicesDeliveryConnected
          partId={DEFAULT_PART_ID}
          unselectedIcon={<Radio.Unchecked disabled={isEvaluated(uiState)} />}
          selectedIcon={
            !isEvaluated(uiState) ? (
              <Radio.Checked />
            ) : isCorrect(uiState.attemptState) ? (
              <Radio.Correct />
            ) : (
              <Radio.Incorrect />
            )
          }
          onSelect={(id) => dispatch(setSelection(DEFAULT_PART_ID, id, onSaveActivity, 'single'))}
        />
        <ResetButtonConnected
          onReset={() => dispatch(resetAction(onResetActivity, { [DEFAULT_PART_ID]: [] }))}
        />
        <SubmitButtonConnected />
        <HintsDeliveryConnected partId={DEFAULT_PART_ID} />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class MultipleChoiceDelivery extends DeliveryElement<MCSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<MCSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);

    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <MultipleChoiceComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, MultipleChoiceDelivery);
