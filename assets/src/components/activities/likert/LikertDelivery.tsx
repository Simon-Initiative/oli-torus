import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import {
  ActivityDeliveryState,
  PartInputs,
  activityDeliverySlice,
  initializeState,
  isEvaluated,
  listenForParentSurveyReset,
  listenForParentSurveySubmit,
  listenForReviewAttemptChange,
  resetAction,
  setSelection,
  submit,
} from 'data/activities/DeliveryState';
import { initialPartInputs } from 'data/activities/utils';
import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { ScoreAsYouGoHeader } from '../common/ScoreAsYouGoHeader';
import { ScoreAsYouGoSubmitReset } from '../common/ScoreAsYouGoSubmitReset';
import { SubmitResetConnected } from '../common/delivery/SubmitReset';
import { EvaluationConnected } from '../common/delivery/evaluation/EvaluationConnected';
import { GradedPointsConnected } from '../common/delivery/graded_points/GradedPointsConnected';
import { HintsDeliveryConnected } from '../common/hints/delivery/HintsDeliveryConnected';
import { StemDelivery } from '../common/stem/delivery/StemDelivery';
import { castPartId } from '../common/utils';
import * as ActivityTypes from '../types';
import { LikertTable } from './Sections/LikertTable';
import { LikertModelSchema } from './schema';

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
    listenForReviewAttemptChange(model, activityState.activityId as number, dispatch, context);

    dispatch(
      initializeState(activityState, initialPartInputs(model, activityState), model, context),
    );
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

  const submitReset =
    !uiState.activityContext.graded || uiState.activityContext.batchScoring ? (
      <SubmitResetConnected
        onReset={() => dispatch(resetAction(onResetActivity, emptySelectionMap))}
      />
    ) : (
      <ScoreAsYouGoSubmitReset
        onSubmit={() => dispatch(submit(onSubmitActivity))}
        onReset={() => dispatch(resetAction(onResetActivity, undefined))}
      />
    );

  return (
    <div className="activity multiple-choice-activity">
      <div className="activity-content">
        <ScoreAsYouGoHeader />
        <StemDelivery stem={(uiState.model as LikertModelSchema).stem} context={writerContext} />
        <LikertTable
          model={uiState.model as LikertModelSchema}
          isSelected={isSelected}
          onSelect={onSelect}
          disabled={isEvaluated(uiState)}
          context={writerContext}
        />
        <GradedPointsConnected />

        {submitReset}

        <HintsDeliveryConnected
          partId={castPartId(activityState.parts[0].partId)}
          resetPartInputs={emptySelectionMap}
        />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class LikertDelivery extends DeliveryElement<LikertModelSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<LikertModelSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer, { name: 'LikertDelivery' });
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
