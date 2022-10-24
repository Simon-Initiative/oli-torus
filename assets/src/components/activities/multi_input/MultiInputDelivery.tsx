import { Evaluation } from 'components/activities/common/delivery/evaluation/Evaluation';
import { Submission } from 'components/activities/common/delivery/evaluation/Submission';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submit_button/SubmitButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { DeliveryElement, DeliveryElementProps } from 'components/activities/DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { MultiInputSchema, MultiInput } from 'components/activities/multi_input/schema';
import { Manifest, PartId } from 'components/activities/types';
import { toSimpleText } from 'components/editing/slateUtils';
import {
  activityDeliverySlice,
  ActivityDeliveryState,
  initializeState,
  isEvaluated,
  listenForParentSurveySubmit,
  listenForParentSurveyReset,
  listenForReviewAttemptChange,
  submitPart,
  PartInputs,
  resetAction,
} from 'data/activities/DeliveryState';
import { getByUnsafe } from 'data/activities/model/utils';
import { safelySelectInputs } from 'data/activities/utils';
import { defaultWriterContext } from 'data/content/writers/context';
import React, { useEffect, useRef } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import { initializePersistence } from '../common/delivery/persistence';

export const MultiInputComponent: React.FC = () => {
  const {
    state: activityState,
    context,
    onSubmitActivity,
    onSaveActivity,
    onSubmitPart,
    onResetActivity,
    mode,
    model,
  } = useDeliveryElementContext<MultiInputSchema>();

  const { surveyId, sectionSlug, bibParams } = context;
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const [hintsShown, setHintsShown] = React.useState<PartId[]>([]);
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
        safelySelectInputs(activityState).caseOf({
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
    setHintsShown((hintsShown) =>
      hintsShown.includes(input.partId)
        ? hintsShown.filter((id) => id !== input.partId)
        : hintsShown.concat(input.partId),
    );
  };

  const inputs = new Map(
    (uiState.model as MultiInputSchema).inputs.map((input) => [
      input.id,
      {
        input:
          input.inputType === 'dropdown'
            ? {
                id: input.id,
                inputType: input.inputType,
                options: (uiState.model as MultiInputSchema).choices
                  .filter((c) => input.choiceIds.includes(c.id))
                  .map((choice) => ({
                    value: choice.id,
                    displayValue: toSimpleText(choice.content),
                  })),
              }
            : { id: input.id, inputType: input.inputType },
        value: (uiState.partState[input.partId]?.studentInput || [''])[0],
        hasHints: uiState.partState[input.partId].hasMoreHints,
      },
    ]),
  );

  const handlePerPartSubmission = (partId: string, input: string | null = null) => {
    const partState = uiState.partState[partId];
    const part = uiState.attemptState.parts.find((p) => p.partId === partId);
    const payload = input === null ? { input: partState.studentInput[0] } : { input };
    dispatch(
      submitPart(
        uiState.attemptState.attemptGuid,
        part?.attemptGuid as string,
        payload,
        onSubmitPart,
      ),
    );
  };

  // When an input changes value, we always update the internal state. Then, depending on the
  // type of the input and the submitPerPart setting, we take different actions:
  //
  // 1. For dropdowns, we either submit that part, or save immediately
  // 2. For other types (text and numeric inputs), we schedule a deferred save
  //
  const onChange = (id: string, value: string) => {
    const input = getByUnsafe((uiState.model as MultiInputSchema).inputs, (x) => x.id === id);

    dispatch(
      activityDeliverySlice.actions.setStudentInputForPart({
        partId: input.partId,
        studentInput: [value],
      }),
    );

    const fn = () =>
      onSaveActivity(uiState.attemptState.attemptGuid, [
        {
          attemptGuid: getByUnsafe(uiState.attemptState.parts, (p) => p.partId === input.partId)
            .attemptGuid,
          response: { input: value },
        },
      ]);

    if (input.inputType === 'dropdown') {
      if ((uiState.model as MultiInputSchema).submitPerPart) {
        handlePerPartSubmission(input.partId, value);
      } else {
        fn();
      }
    } else {
      deferredSaves.current[id].save(fn);
    }
  };

  // When inputs of type other than dropdown lose their focus:
  // 1. We flush pending changes, so we save their state if the student's next interaction is to navigate
  //    away to another page
  // 2. If submitPerPart is active, we then submit the part
  const onBlur = (id: string) => {
    const input = getByUnsafe((uiState.model as MultiInputSchema).inputs, (x) => x.id === id);
    if (input.inputType !== 'dropdown') {
      deferredSaves.current[id].flushPendingChanges(false);
      if ((uiState.model as MultiInputSchema).submitPerPart) {
        handlePerPartSubmission(input.partId);
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
      inputs,
      disabled: isEvaluated(uiState),
    },
  });

  return (
    <div className="activity mc-activity">
      <div className="activity-content">
        <StemDelivery
          className="form-inline"
          stem={(uiState.model as MultiInputSchema).stem}
          context={writerContext}
        />
        <GradedPointsConnected />
        <ResetButtonConnected
          onReset={() => dispatch(resetAction(onResetActivity, emptyPartInputs))}
        />
        {(uiState.model as MultiInputSchema).submitPerPart ? null : (
          <SubmitButtonConnected disabled={false} />
        )}
        {hintsShown.map((partId) => (
          <HintsDeliveryConnected
            key={partId}
            partId={partId}
            shouldShow={hintsShown.includes(partId)}
          />
        ))}
        <Evaluation
          shouldShow={
            anyEvaluated(uiState) && surveyId === null && (!context.graded || mode === 'review')
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
export class MultiInputDelivery extends DeliveryElement<MultiInputSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<MultiInputSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer);
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
