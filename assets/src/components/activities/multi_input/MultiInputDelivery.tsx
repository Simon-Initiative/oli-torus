import React, { useEffect, useRef } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { DeliveryElement, DeliveryElementProps } from 'components/activities/DeliveryElement';
import { Evaluation } from 'components/activities/common/delivery/evaluation/Evaluation';
import { Submission } from 'components/activities/common/delivery/evaluation/Submission';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { Choice, Manifest, PartId } from 'components/activities/types';
import { toSimpleText } from 'components/editing/slateUtils';
import {
  ActivityDeliveryState,
  PartInputs,
  activityDeliverySlice,
  initializeState,
  isEvaluated,
  listenForParentSurveyReset,
  listenForParentSurveySubmit,
  listenForReviewAttemptChange,
  requestHint,
  resetAction,
  resetAndSavePart,
  resetAndSubmitPart,
  submit,
  submitPart,
} from 'data/activities/DeliveryState';
import { getByUnsafe } from 'data/activities/model/utils';
import { safelySelectStringInputs } from 'data/activities/utils';
import { defaultWriterContext } from 'data/content/writers/context';
import { configureStore } from 'state/store';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { ScoreAsYouGoHeader } from '../common/ScoreAsYouGoHeader';
import { ScoreAsYouGoSubmitReset } from '../common/ScoreAsYouGoSubmitReset';
import { SubmitResetConnected } from '../common/delivery/SubmitReset';
import { initializePersistence } from '../common/delivery/persistence';
import { getOrderedPartIds } from './utils';

export const MultiInputComponent: React.FC = () => {
  const {
    state: activityState,
    context,
    onSubmitActivity,
    onSaveActivity,
    onSubmitPart,
    onResetPart,
    onResetActivity,
    onRequestHint,
    mode,
    model,
  } = useDeliveryElementContext<MultiInputSchema>();

  const { surveyId, sectionSlug, bibParams } = context;
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const [hintsShown, setHintsShown] = React.useState<PartId[]>([]);

  const [orderedPartIds] = React.useState(getOrderedPartIds(model));

  const [isInputDirty, setInputDirty] = React.useState(
    activityState.parts.reduce((acc: any, part) => {
      acc[part.partId] = false;
      return acc;
    }, {}),
  );

  const deferredSaves = useRef(
    model.inputs.reduce((m: any, input: MultiInput) => {
      const p = initializePersistence();
      m[input.id] = p;
      return m;
    }, {}),
  );
  const dispatch = useDispatch();

  const emptyPartInputs = model.inputs.reduce((acc: any, input: any) => {
    acc[input.partId] = [''];
    return acc;
  }, {} as PartInputs);

  useEffect(() => {
    listenForParentSurveySubmit(surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(surveyId, dispatch, onResetActivity, emptyPartInputs);
    listenForReviewAttemptChange(model, activityState.activityId as number, dispatch, context);

    dispatch(
      initializeState(
        activityState,
        safelySelectStringInputs(activityState).caseOf({
          just: (inputs) => inputs,
          nothing: () =>
            model.inputs.reduce((acc, input) => {
              acc[input.partId] = [''];
              return acc;
            }, {} as PartInputs),
        }),
        model,
        context,
      ),
    );
  }, []);

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  const toggleHints = (id: string) => {
    const input = getByUnsafe((uiState.model as MultiInputSchema).inputs, (x) => x.id === id);

    dispatch(requestHint(input.partId, onRequestHint));

    setHintsShown((hintsShown) =>
      hintsShown.includes(input.partId) ? hintsShown : hintsShown.concat(input.partId),
    );
  };

  const choiceIdToChoiceMap: Record<string, Choice> = (
    uiState.model as MultiInputSchema
  ).choices.reduce(
    (acc, choice) => ({
      ...acc,
      [choice.id]: choice,
    }),
    {},
  );

  const inputs = new Map(
    (uiState.model as MultiInputSchema).inputs.map((input) => [
      input.id,
      {
        input:
          input.inputType === 'dropdown'
            ? {
                id: input.id,
                inputType: input.inputType,
                options: input.choiceIds.map((choiceId) => ({
                  value: choiceId,
                  displayValue: toSimpleText(choiceIdToChoiceMap[choiceId].content),
                })),
                size: input.size,
              }
            : { id: input.id, inputType: input.inputType, size: input.size },
        value: (uiState.partState[input.partId]?.studentInput || [''])[0],
        hasHints: !context.graded && uiState.partState[input.partId].hasMoreHints,
      },
    ]),
  );

  const handlePerPartSubmission = (partId: string, input: string | null = null) => {
    const partState = uiState.partState[partId];
    const part = uiState.attemptState.parts.find((p) => p.partId === partId);

    const payload = input === null ? { input: partState.studentInput[0] } : { input };

    if (part !== undefined) {
      if (part.dateEvaluated !== null) {
        dispatch(
          resetAndSubmitPart(
            uiState.attemptState.attemptGuid,
            part?.attemptGuid as string,
            payload,
            onResetPart,
            onSubmitPart,
          ),
        );
      } else {
        dispatch(
          submitPart(
            uiState.attemptState.attemptGuid,
            part?.attemptGuid as string,
            payload,
            onSubmitPart,
          ),
        );
      }
    }
  };

  // When an input changes value, we always update the internal state. Then, depending on the
  // type of the input and the submitPerPart setting, we take different actions:
  //
  // 1. For dropdowns, we either submit that part, or save immediately
  // 2. For other types (text and numeric inputs), we schedule a deferred save
  //
  const onChange = (id: string, value: string) => {
    const input = getByUnsafe((uiState.model as MultiInputSchema).inputs, (x) => x.id === id);
    const part = uiState.attemptState.parts.find((p) => p.partId === input.partId);
    const response = { input: value };

    if (part !== undefined) {
      // Here we handle the case that the student is typing again into an input whose
      // part attempt had already been evaluated. So we must first reset to get a new
      // part attempt, then either submit (if dropdown) or save the input to that part attempt
      if (part.dateEvaluated !== null && (uiState.model as MultiInputSchema).submitPerPart) {
        if (input.inputType === 'dropdown') {
          const payload = { input: value };
          dispatch(
            resetAndSubmitPart(
              uiState.attemptState.attemptGuid,
              part?.attemptGuid as string,
              payload,
              onResetPart,
              onSubmitPart,
            ),
          );
        } else {
          dispatch(
            resetAndSavePart(
              uiState.attemptState.attemptGuid,
              part.attemptGuid,
              part.partId as string,
              response,
              onSaveActivity,
              onResetPart,
            ),
          );
        }
      } else {
        // Otherwise this is just a change to an existing active part attempt

        dispatch(
          activityDeliverySlice.actions.setStudentInputForPart({
            partId: input.partId,
            studentInput: [value],
          }),
        );

        const doSave = () =>
          onSaveActivity(uiState.attemptState.attemptGuid, [
            {
              attemptGuid: part.attemptGuid,
              response: { input: value },
            },
          ]);

        if (input.inputType === 'dropdown') {
          if ((uiState.model as MultiInputSchema).submitPerPart && !context.graded) {
            handlePerPartSubmission(input.partId, value);
          } else {
            doSave();
          }
        } else {
          doSave();
        }
      }

      if (!isInputDirty[id]) {
        setInputDirty(Object.assign({}, isInputDirty, { [id]: true }));
      }
    }
  };

  const hasActualInput = (id: string) => {
    const input = getByUnsafe((uiState.model as MultiInputSchema).inputs, (x) => x.id === id);
    const studentInput = uiState.partState[input.partId].studentInput[0];

    return studentInput !== undefined && studentInput.trim() !== '';
  };

  // When inputs of type other than dropdown lose their focus:
  // 1. We flush pending changes, so we save their state if the student's next interaction is to navigate
  //    away to another page
  // 2. If submitPerPart is active, we then submit the part
  const onBlur = (id: string) => {
    const input = getByUnsafe((uiState.model as MultiInputSchema).inputs, (x) => x.id === id);
    if (input.inputType !== 'dropdown' && hasActualInput(id)) {
      deferredSaves.current[id].flushPendingChanges(false);
      if (
        (uiState.model as MultiInputSchema).submitPerPart &&
        !context.graded &&
        isInputDirty[id as any]
      ) {
        handlePerPartSubmission(input.partId);
        setInputDirty(Object.assign({}, isInputDirty, { [id]: false }));
      }
    }
  };

  const onPressEnter = (id: string) => {
    const input = getByUnsafe((uiState.model as MultiInputSchema).inputs, (x) => x.id === id);
    if (hasActualInput(id)) {
      deferredSaves.current[id].flushPendingChanges(false);
      if ((uiState.model as MultiInputSchema).submitPerPart && !context.graded) {
        handlePerPartSubmission(input.partId);
        setInputDirty(Object.assign({}, isInputDirty, { [id]: false }));
      }
    }
  };

  const anyEvaluated = (state: ActivityDeliveryState) =>
    state.attemptState.dateEvaluated !== null ||
    state.attemptState.parts.some((p) => p.dateEvaluated !== null);

  const writerContext = defaultWriterContext({
    graded: context.graded,
    sectionSlug,
    bibParams,
    inputRefContext: {
      toggleHints,
      onChange,
      onBlur,
      onPressEnter,
      inputs,
      disabled: isEvaluated(uiState),
    },
  });

  const submitPerPart = (uiState.model as MultiInputSchema).submitPerPart;
  return (
    <div className="activity multi-input-activity">
      <div className="activity-content">
        <ScoreAsYouGoHeader />
        <StemDelivery
          className="form-inline"
          stem={(uiState.model as MultiInputSchema).stem}
          context={writerContext}
        />
        <GradedPointsConnected />
        {/*
          When submitPerPart is active, we don't show the submit button, only reset
          When submitPerPart is not active, we show both
         */}
        {submitPerPart && (
          <ResetButtonConnected
            onReset={() => dispatch(resetAction(onResetActivity, emptyPartInputs))}
          />
        )}
        {submitPerPart || (
          <SubmitResetConnected
            onReset={() => dispatch(resetAction(onResetActivity, emptyPartInputs))}
            submitDisabled={false}
          />
        )}

        <ScoreAsYouGoSubmitReset
          onSubmit={() => dispatch(submit(onSubmitActivity))}
          onReset={() => dispatch(resetAction(onResetActivity, undefined))}
        />

        {hintsShown.map((partId) => (
          <HintsDeliveryConnected
            key={partId}
            partId={partId}
            shouldShow={hintsShown.includes(partId)}
            resetPartInputs={emptyPartInputs}
          />
        ))}
        <Evaluation
          shouldShow={
            context.showFeedback == true &&
            anyEvaluated(uiState) &&
            surveyId === null &&
            (!context.graded || mode === 'review' || context.oneAtATime || !context.batchScoring)
          }
          attemptState={uiState.attemptState}
          context={writerContext}
          partOrder={orderedPartIds}
        />
        <Submission attemptState={uiState.attemptState} surveyId={surveyId} />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class MultiInputDelivery extends DeliveryElement<MultiInputSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<MultiInputSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer, { name: 'MultiInputDelivery' });
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <MultiInputComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.delivery.element, MultiInputDelivery);
