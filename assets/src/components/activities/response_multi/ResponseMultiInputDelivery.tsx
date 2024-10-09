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
import { ResponseMultiInputSchema } from 'components/activities/response_multi/schema';
import { ActivityModelSchema, Choice, Manifest, PartId } from 'components/activities/types';
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
  submitPart,
} from 'data/activities/DeliveryState';
import { getByUnsafe } from 'data/activities/model/utils';
import { safelySelectStringInputs } from 'data/activities/utils';
import { defaultWriterContext } from 'data/content/writers/context';
import { configureStore } from 'state/store';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { SubmitResetConnected } from '../common/delivery/SubmitReset';
import { initializePersistence } from '../common/delivery/persistence';
import { MultiInput } from '../multi_input/schema';

export const ResponseMultiInputComponent: React.FC = () => {
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
  } = useDeliveryElementContext<ResponseMultiInputSchema>();

  const { surveyId, sectionSlug, bibParams } = context;
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const [hintsShown, setHintsShown] = React.useState<PartId[]>([]);

  const [isInputDirty, setInputDirty] = React.useState(
    activityState.parts.reduce((acc: any, part) => {
      acc[part.partId] = false;
      return acc;
    }, {}),
  );

  const deferredSaves = useRef(
    model.inputs.reduce((m: any, input: MultiInput) => {
      const p = initializePersistence(750, 1200);
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
    const input = getByUnsafe(
      (uiState.model as ResponseMultiInputSchema).inputs,
      (x) => x.id === id,
    );

    dispatch(requestHint(input.partId, onRequestHint));

    setHintsShown((hintsShown) =>
      hintsShown.includes(input.partId) ? hintsShown : hintsShown.concat(input.partId),
    );
  };

  const choiceIdToChoiceMap: Record<string, Choice> = (
    uiState.model as ResponseMultiInputSchema
  ).choices.reduce(
    (acc, choice) => ({
      ...acc,
      [choice.id]: choice,
    }),
    {},
  );

  const extractValue = (inputId: string, v: string[]) => {
    if (v[0] && (uiState.model as ResponseMultiInputSchema).multInputsPerPart) {
      const vj = JSON.parse(v[0]);
      if (vj) {
        return vj[inputId];
      }
    }
    return v[0];
  };

  const inputs = new Map(
    (uiState.model as ResponseMultiInputSchema).inputs.map((input) => [
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
        value: extractValue(
          input.id,
          (uiState.partState[input.partId]?.studentInput as string[]) || [''],
        ),
        hasHints: !context.graded && uiState.partState[input.partId].hasMoreHints,
      },
    ]),
  );

  const submitPerPart = (uiState.model as ResponseMultiInputSchema).submitPerPart;

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
    const input = getByUnsafe(
      (uiState.model as ResponseMultiInputSchema).inputs,
      (x) => x.id === id,
    );

    // This is full part attempt state
    const part = uiState.attemptState.parts.find((p) => p.partId === input.partId);
    if (part === undefined) {
      console.log('part attempt state not found on change');
    }

    // this fragment of delivery state has studentInput = [] before first save
    const partState = uiState.partState[input.partId];
    const prevInput = partState.studentInput[0];
    const values = prevInput ? JSON.parse(prevInput) : {};
    values[input.id] = value;
    const studentInput = JSON.stringify(values);

    const response = { input: studentInput };

    // auto submit if dropdown choice completes part. text changes auto submit on Blur
    const autoSubmit =
      submitPerPart &&
      !context.graded &&
      input.inputType === 'dropdown' &&
      inputPartComplete(input, uiState.model);

    if (part !== undefined) {
      // Here we handle the case that the student is typing again into an input whose
      // part attempt had already been evaluated. So we must first reset to get a new
      // part attempt, then either submit if appropriate or save to that part attempt
      if (part.dateEvaluated !== null) {
        if (autoSubmit) {
          dispatch(
            resetAndSubmitPart(
              uiState.attemptState.attemptGuid,
              part?.attemptGuid as string,
              response,
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
            studentInput: [studentInput],
          }),
        );

        const saveFn = () =>
          onSaveActivity(uiState.attemptState.attemptGuid, [
            {
              attemptGuid: part.attemptGuid,
              response: { input: studentInput },
            },
          ]);

        if (autoSubmit) {
          handlePerPartSubmission(input.partId, studentInput);
        } else if (input.inputType === 'dropdown') {
          saveFn();
        } else {
          deferredSaves.current[id].save(saveFn);
        }
      }

      if (!isInputDirty[id]) {
        setInputDirty(Object.assign({}, isInputDirty, { [id]: true }));
      }
    }
  };

  const hasActualInput = (id: string) => {
    const input = getByUnsafe(
      (uiState.model as ResponseMultiInputSchema).inputs,
      (x) => x.id === id,
    );
    const studentInput: string = uiState.partState[input.partId].studentInput[0];
    const values = studentInput ? JSON.parse(studentInput) : {};

    return studentInput !== undefined && values[id] !== undefined && values[id].trim() !== '';
  };

  // for submitPerPart: use when given input has value to test if
  // all *other* part inputs have values so part is now complete
  const inputPartComplete = (input: any, model: ActivityModelSchema) =>
    (model as ResponseMultiInputSchema).inputs
      .filter((inp) => inp.partId == input.partId)
      .filter((inp) => inp.id !== input.id)
      .map((inp) => inp.id)
      .every(hasActualInput);

  // When inputs of type other than dropdown lose their focus:
  // 1. We flush pending changes, so we save their state if the student's next interaction is to navigate
  //    away to another page
  // 2. If submitPerPart is active, we then submit the part if it is complete
  const onBlur = (id: string) => {
    const input = getByUnsafe(
      (uiState.model as ResponseMultiInputSchema).inputs,
      (x) => x.id === id,
    );
    if (input.inputType !== 'dropdown' && hasActualInput(id)) {
      deferredSaves.current[id].flushPendingChanges(false);

      if (
        submitPerPart &&
        !context.graded &&
        isInputDirty[id as any] &&
        inputPartComplete(input, uiState.model)
      ) {
        handlePerPartSubmission(input.partId);
        setInputDirty(Object.assign({}, isInputDirty, { [id]: false }));
      }
    }
  };

  const onPressEnter = (id: string) => {
    const input = getByUnsafe(
      (uiState.model as ResponseMultiInputSchema).inputs,
      (x) => x.id === id,
    );
    if (hasActualInput(id)) {
      deferredSaves.current[id].flushPendingChanges(false);
      if (submitPerPart && !context.graded && inputPartComplete(input, uiState.model)) {
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

  return (
    <div className="activity response-multi-input-activity">
      <div className="activity-content">
        <StemDelivery
          className="form-inline"
          stem={(uiState.model as ResponseMultiInputSchema).stem}
          context={writerContext}
        />
        <GradedPointsConnected />

        {/*
          When submitPerPart - only display reset button
          When not submitPerPart - display reset & submit buttons
        */}
        {submitPerPart ? (
          <ResetButtonConnected
            onReset={() => dispatch(resetAction(onResetActivity, emptyPartInputs))}
          />
        ) : (
          <SubmitResetConnected
            onReset={() => dispatch(resetAction(onResetActivity, emptyPartInputs))}
            submitDisabled={false}
          />
        )}

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
            (!context.graded || mode === 'review')
          }
          attemptState={uiState.attemptState}
          context={writerContext}
        />
        <Submission attemptState={uiState.attemptState} surveyId={surveyId} />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class ResponseMultiInputDelivery extends DeliveryElement<ResponseMultiInputSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<ResponseMultiInputSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer, {
      name: 'ResponseMultiInputDelivery',
    });
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <ResponseMultiInputComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.delivery.element, ResponseMultiInputDelivery);
