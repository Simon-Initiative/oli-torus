import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { StemDeliveryConnected } from 'components/activities/common/stem/delivery/StemDelivery';
import { ResponseChoices } from 'components/activities/ordering/sections/ResponseChoices';
import {
  ActivityDeliveryState,
  activityDeliverySlice,
  initializeState,
  isEvaluated,
  isSubmitted,
  listenForParentSurveyReset,
  listenForParentSurveySubmit,
  listenForReviewAttemptChange,
  resetAction,
  submit,
} from 'data/activities/DeliveryState';
import { Choices } from 'data/activities/model/choices';
import { initialPartInputs, studentInputToString } from 'data/activities/utils';
import { elementsOfType } from 'data/content/utils';
import { configureStore } from 'state/store';
import { DeliveryElement, DeliveryElementProps } from '../DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { ScoreAsYouGoHeader } from '../common/ScoreAsYouGoHeader';
import { ScoreAsYouGoSubmitReset } from '../common/ScoreAsYouGoSubmitReset';
import { SubmitResetConnected } from '../common/delivery/SubmitReset';
import { castPartId } from '../common/utils';
import * as ActivityTypes from '../types';
import { OrderingSchema } from './schema';

export const OrderingComponent: React.FC = () => {
  const {
    model,
    mode,
    context,
    state: activityState,
    onSubmitActivity,
    onResetActivity,
    onSaveActivity,
  } = useDeliveryElementContext<OrderingSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const { writerContext } = useDeliveryElementContext();

  const dispatch = useDispatch();
  const { surveyId } = context;
  const onSelectionChange = (studentInput: ActivityTypes.ChoiceId[]) => {
    dispatch(
      activityDeliverySlice.actions.setStudentInputForPart({
        partId: castPartId(activityState.parts[0].partId),
        studentInput,
      }),
    );

    onSaveActivity(uiState.attemptState.attemptGuid, [
      {
        attemptGuid: uiState.attemptState.parts[0].attemptGuid,
        response: { input: studentInputToString(studentInput) },
      },
    ]);
  };

  const defaultPartInputs = {
    [castPartId(activityState.parts[0].partId)]: model.choices.map((choice) => choice.id),
  };

  useEffect(() => {
    listenForParentSurveySubmit(surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(surveyId, dispatch, onResetActivity, defaultPartInputs);
    listenForReviewAttemptChange(model, activityState.activityId as number, dispatch, context);

    dispatch(
      initializeState(
        activityState,
        initialPartInputs(model, activityState, {
          [castPartId(activityState.parts[0].partId)]: model.choices.map((c) => c.id),
        }),
        model,
        context,
      ),
    );

    // Ensure when the initial state is null that we set the state to match
    // the initial choice ordering.  This allows submissions without student interaction
    // to be evaluated correctly.
    setTimeout(() => {
      if (activityState.parts[0].response === null && uiState.model) {
        const selection = (uiState.model as OrderingSchema).choices.map((choice) => choice.id);
        const input = studentInputToString(selection);
        onSaveActivity(activityState.attemptGuid, [
          {
            attemptGuid: activityState.parts[0].attemptGuid,
            response: { input },
          },
        ]);
      }
    }, 0);
  }, []);

  // For Play All function used on ordering questions with audio choices
  const [playingAll, setPlayingAll] = React.useState<boolean>(false);
  const player = React.useRef<HTMLAudioElement>(null);

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  const studentInput =
    uiState.partState[castPartId(uiState.attemptState.parts[0].partId)]?.studentInput;

  // If there is user state, let that drive the order of choices.  If there is no user state,
  // just use the ordering inherent in the choices from the model.  This allows student and
  // instructor review use cases to both work.
  const choices =
    studentInput === null || studentInput.length === 0
      ? (uiState.model as ActivityTypes.HasChoices).choices
      : studentInput.map((id) => Choices.getOne(uiState.model as OrderingSchema, id));

  // collect choice audio URL list in current order for the playAll function
  const audioUrls = choices
    .map((c) => elementsOfType(c.content, 'audio')[0])
    .filter((e) => e !== undefined)
    .map((e: any) => e.src);

  const playAll = ([first, ...rest]: string[]): void => {
    if (player.current) {
      player.current.src = first;
      player.current.onended = () => (rest.length > 0 ? playAll(rest) : setPlayingAll(false));
      player.current.play();
      setPlayingAll(true);
    }
  };

  const stopPlayingAll = () => {
    if (player.current) player.current.pause();
    setPlayingAll(false);
  };

  const submitReset =
    !uiState.activityContext.graded || uiState.activityContext.batchScoring ? (
      <SubmitResetConnected
        onReset={() => dispatch(resetAction(onResetActivity, defaultPartInputs))}
      />
    ) : (
      <ScoreAsYouGoSubmitReset
        mode={mode}
        onSubmit={() => dispatch(submit(onSubmitActivity))}
        onReset={() => dispatch(resetAction(onResetActivity, undefined))}
      />
    );

  return (
    <div className="activity ordering-activity">
      <div className="activity-content">
        <ScoreAsYouGoHeader />
        <StemDeliveryConnected />
        <GradedPointsConnected />
        <ResponseChoices
          writerContext={writerContext}
          choices={choices}
          colorMap={model.choiceColors ? new Map(model.choiceColors) : undefined}
          setChoices={(choices) => onSelectionChange(choices.map((c) => c.id))}
          disabled={isEvaluated(uiState) || isSubmitted(uiState)}
        />
        {audioUrls.length > 0 && (
          <div>
            <button
              className="btn btn-primary self-start mt-3 mb-3"
              aria-label="Play All"
              onClick={() => (playingAll ? stopPlayingAll() : playAll(audioUrls))}
            >
              {playingAll ? 'Stop Playing All' : 'Play All'}
            </button>
            <audio ref={player} />
          </div>
        )}

        {submitReset}

        <HintsDeliveryConnected
          partId={castPartId(activityState.parts[0].partId)}
          resetPartInputs={defaultPartInputs}
        />
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class OrderingDelivery extends DeliveryElement<OrderingSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<OrderingSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer, { name: 'OrderingDelivery' });
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
