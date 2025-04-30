import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDelivery';
import { ActivityModelSchema, HasChoices } from 'components/activities/types';
import { Radio } from 'components/misc/icons/radio/Radio';
import {
  ActivityDeliveryState,
  activityDeliverySlice,
  initializeState,
  isEvaluated,
  listenForParentSurveyReset,
  listenForParentSurveySubmit,
  listenForReviewAttemptChange,
  resetAction,
  resetAndSubmitActivity,
  setSelection,
  submit,
} from 'data/activities/DeliveryState';
import { initialPartInputs, isCorrect } from 'data/activities/utils';
import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { ScoreAsYouGoHeader } from '../common/ScoreAsYouGoHeader';
import { ScoreAsYouGoSubmitReset } from '../common/ScoreAsYouGoSubmitReset';
import { castPartId } from '../common/utils';
import * as ActivityTypes from '../types';
import { MCSchema } from './schema';

// Used instead of the real 'onSaveActivity' to bypass saving state to the server when we are just
// about to submit that state with a submission. This saves a network call that isn't necessary and avoids
// perhaps a weird race condition (where the submit request could arrive before the save)
const noOpSave = (
  _guid: string,
  _partResponses: ActivityTypes.PartResponse[],
): Promise<ActivityTypes.Success> => Promise.resolve({ type: 'success' });

export const MultipleChoiceComponent: React.FC = () => {
  const {
    state: activityState,
    context,
    onSubmitActivity,
    onSaveActivity,
    onResetActivity,
    model,
  } = useDeliveryElementContext<MCSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();
  const { surveyId } = context;
  const { writerContext } = useDeliveryElementContext<HasChoices & ActivityModelSchema>();

  useEffect(() => {
    listenForParentSurveySubmit(surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(surveyId, dispatch, onResetActivity, {
      [activityState.parts[0].partId]: [],
    });

    listenForReviewAttemptChange(model, activityState.activityId as number, dispatch, context);
    dispatch(
      initializeState(activityState, initialPartInputs(model, activityState), model, context),
    );
  }, []);

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  const saveOrSubmit =
    context.graded || context.surveyId !== null
      ? (id: string) =>
          dispatch(
            setSelection(castPartId(activityState.parts[0].partId), id, onSaveActivity, 'single'),
          )
      : (input: string) => {
          if (uiState.attemptState.dateEvaluated !== null) {
            dispatch(
              setSelection(castPartId(activityState.parts[0].partId), input, noOpSave, 'single'),
            );

            dispatch(
              resetAndSubmitActivity(
                uiState.attemptState.attemptGuid,
                [{ input }],
                onResetActivity,
                onSubmitActivity,
              ),
            );
          } else {
            dispatch(
              setSelection(castPartId(activityState.parts[0].partId), input, noOpSave, 'single'),
            );
            dispatch(submit(onSubmitActivity));
          }
        };

  return (
    <div className="activity mc-activity">
      <div className="activity-content">
        <ScoreAsYouGoHeader />
        <StemDeliveryConnected />
        <GradedPointsConnected />
        <ChoicesDelivery
          unselectedIcon={<Radio.Unchecked disabled={isEvaluated(uiState) && context.graded} />}
          selectedIcon={
            !isEvaluated(uiState) || !context.graded ? (
              <Radio.Checked />
            ) : isCorrect(uiState.attemptState) ? (
              <Radio.Correct />
            ) : (
              <Radio.Incorrect />
            )
          }
          choices={(uiState.model as HasChoices).choices}
          selected={uiState.partState[activityState.parts[0].partId]?.studentInput || []}
          onSelect={(id) => saveOrSubmit(id)}
          isEvaluated={isEvaluated(uiState) && context.graded}
          context={writerContext}
        />
        <ScoreAsYouGoSubmitReset
          onSubmit={() => dispatch(submit(onSubmitActivity))}
          onReset={() => dispatch(resetAction(onResetActivity, undefined))}
        />
        <HintsDeliveryConnected
          partId={castPartId(activityState.parts[0].partId)}
          resetPartInputs={{ [activityState.parts[0].partId]: [] }}
        />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class MultipleChoiceDelivery extends DeliveryElement<MCSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<MCSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer, {
      name: 'MultipleChoiceDelivery',
    });

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
