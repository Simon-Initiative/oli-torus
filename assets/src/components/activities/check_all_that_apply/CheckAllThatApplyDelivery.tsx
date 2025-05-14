import React, { useEffect, useMemo } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { CATASchema } from 'components/activities/check_all_that_apply/schema';
import { ChoicesDeliveryConnected } from 'components/activities/common/choices/delivery/ChoicesDeliveryConnected';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDelivery';
import { Manifest } from 'components/activities/types';
import { Checkbox } from 'components/misc/icons/checkbox/Checkbox';
import {
  ActivityDeliveryState,
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
import { initialPartInputs, isCorrect } from 'data/activities/utils';
import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { ScoreAsYouGoHeader } from '../common/ScoreAsYouGoHeader';
import { ScoreAsYouGoSubmitReset } from '../common/ScoreAsYouGoSubmitReset';
import { SubmitResetConnected } from '../common/delivery/SubmitReset';
import { castPartId } from '../common/utils';

export const CheckAllThatApplyComponent: React.FC = () => {
  const {
    state: activityState,
    context,
    onSubmitActivity,
    onResetActivity,
    onSaveActivity,
    model,
  } = useDeliveryElementContext<CATASchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();
  const { surveyId } = context;
  useEffect(() => {
    listenForParentSurveySubmit(surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(surveyId, dispatch, onResetActivity, {
      [castPartId(activityState.parts[0].partId)]: [],
    });
    listenForReviewAttemptChange(model, activityState.activityId as number, dispatch, context);

    dispatch(
      initializeState(activityState, initialPartInputs(model, activityState), model, context),
    );
  }, []);

  const resetInputs = useMemo(
    () => ({ [castPartId(activityState.parts[0].partId)]: [] }),
    [activityState.parts],
  );

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  const submitReset =
    !uiState.activityContext.graded || uiState.activityContext.batchScoring ? (
      <SubmitResetConnected onReset={() => dispatch(resetAction(onResetActivity, resetInputs))} />
    ) : (
      <ScoreAsYouGoSubmitReset
        onSubmit={() => dispatch(submit(onSubmitActivity))}
        onReset={() => dispatch(resetAction(onResetActivity, undefined))}
      />
    );

  return (
    <div className={`activity cata-activity ${isEvaluated(uiState) ? 'evaluated' : ''}`}>
      <div className="activity-content">
        <ScoreAsYouGoHeader />
        <StemDeliveryConnected />
        <GradedPointsConnected />
        <ChoicesDeliveryConnected
          partId={castPartId(activityState.parts[0].partId)}
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
          onSelect={(id) =>
            dispatch(
              setSelection(
                castPartId(activityState.parts[0].partId),
                id,
                onSaveActivity,
                'multiple',
              ),
            )
          }
        />
        {submitReset}
        <HintsDeliveryConnected
          partId={castPartId(activityState.parts[0].partId)}
          resetPartInputs={resetInputs}
        />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class CheckAllThatApplyDelivery extends DeliveryElement<CATASchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<CATASchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer, { name: 'CATADelivery' });
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
