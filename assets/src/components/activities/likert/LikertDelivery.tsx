import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { LikertModelSchema } from './schema';
import * as ActivityTypes from '../types';
import { StemDelivery } from '../common/stem/delivery/StemDelivery';
import { configureStore } from 'state/store';
import {
  activityDeliverySlice,
  ActivityDeliveryState,
  initializeState,
  setSelection,
  resetAction,
  PartInputs,
  isEvaluated,
  listenForParentSurveySubmit,
  listenForParentSurveyReset,
  listenForReviewAttemptChange,
} from 'data/activities/DeliveryState';
import { Provider, useSelector, useDispatch } from 'react-redux';
import { initialPartInputs } from 'data/activities/utils';
import { SubmitButtonConnected } from '../common/delivery/submit_button/SubmitButtonConnected';
import { HintsDeliveryConnected } from '../common/hints/delivery/HintsDeliveryConnected';
import { EvaluationConnected } from '../common/delivery/evaluation/EvaluationConnected';
import { DEFAULT_PART_ID } from '../common/utils';
import { GradedPointsConnected } from '../common/delivery/graded_points/GradedPointsConnected';
import { ResetButtonConnected } from '../common/delivery/reset_button/ResetButtonConnected';
import { useDeliveryElementContext, DeliveryElementProvider } from '../DeliveryElementProvider';
import { LikertTable } from './Sections/LikertTable';

const LikertComponent: React.FC = () => {
  const {
    state: activityState,
    context,
    model,
    writerContext,
    onSubmitActivity,
    onSaveActivity,
    onResetActivity,
  } = useDeliveryElementContext<LikertModelSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  const emptySelectionMap = model.items.reduce((acc, item) => {
    acc[item.id] = [''];
    return acc;
  }, {} as PartInputs);

  useEffect(() => {
    listenForParentSurveySubmit(context.surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(context.surveyId, dispatch, onResetActivity, emptySelectionMap);
    listenForReviewAttemptChange(activityState.activityId as number, dispatch, context);

    dispatch(initializeState(activityState, initialPartInputs(activityState), model, context));
  }, []);

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  const isSelected = (itemId: string, choiceId: string): boolean => {
    return uiState.partState[itemId].studentInput[0] == choiceId;
  };

  const onSelect = (itemId: string, choiceId: string) => {
    dispatch(setSelection(itemId, choiceId, onSaveActivity, 'single'));
  };

  return (
    <div className="activity multiple-choice-activity">
      <div className="activity-content">
        <StemDelivery stem={(uiState.model as LikertModelSchema).stem} context={writerContext} />
        <LikertTable
          model={uiState.model as LikertModelSchema}
          isSelected={isSelected}
          onSelect={onSelect}
          disabled={isEvaluated(uiState)}
          context={writerContext}
        />
      </div>
      <GradedPointsConnected />
      <ResetButtonConnected
        onReset={() => dispatch(resetAction(onResetActivity, emptySelectionMap))}
      />
      <SubmitButtonConnected />
      <HintsDeliveryConnected partId={DEFAULT_PART_ID} />
      <EvaluationConnected />
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class LikertDelivery extends DeliveryElement<LikertModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<LikertModelSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <LikertComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.delivery.element, LikertDelivery);
