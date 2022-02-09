import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submit_button/SubmitButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import {
  DeliveryElement,
  DeliveryElementProps,
  DeliveryElementProvider,
  useDeliveryElementContext,
} from 'components/activities/DeliveryElement';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { Manifest, PartId } from 'components/activities/types';
import { toSimpleText } from 'components/editing/utils';
import {
  activityDeliverySlice,
  ActivityDeliveryState,
  initializeState,
  isEvaluated,
  PartInputs,
  resetAction,
} from 'data/activities/DeliveryState';
import { getByUnsafe } from 'data/activities/model/utils';
import { safelySelectInputs } from 'data/activities/utils';
import { defaultWriterContext } from 'data/content/writers/context';
import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';

export const MultiInputComponent: React.FC = () => {
  const {
    state: activityState,
    onSaveActivity,
    onResetActivity,
    model,
    sectionSlug,
  } = useDeliveryElementContext<MultiInputSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const [hintsShown, setHintsShown] = React.useState<PartId[]>([]);
  const dispatch = useDispatch();

  useEffect(() => {
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
      ),
    );
  }, []);

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  const toggleHints = (id: string) => {
    const input = getByUnsafe(model.inputs, (x) => x.id === id);
    setHintsShown((hintsShown) =>
      hintsShown.includes(input.partId)
        ? hintsShown.filter((id) => id !== input.partId)
        : hintsShown.concat(input.partId),
    );
  };

  const inputs = new Map(
    model.inputs.map((input) => [
      input.id,
      {
        input:
          input.inputType === 'dropdown'
            ? {
                id: input.id,
                inputType: input.inputType,
                options: model.choices
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

  const onChange = (id: string, e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const input = getByUnsafe(model.inputs, (x) => x.id === id);
    const value = e.target.value;
    dispatch(
      activityDeliverySlice.actions.setStudentInputForPart({
        partId: input.partId,
        studentInput: [value],
      }),
    );

    onSaveActivity(uiState.attemptState.attemptGuid, [
      {
        attemptGuid: getByUnsafe(uiState.attemptState.parts, (p) => p.partId === input.partId)
          .attemptGuid,
        response: { input: value },
      },
    ]);
  };

  const writerContext = defaultWriterContext({
    sectionSlug,
    inputRefContext: {
      toggleHints,
      onChange,
      inputs,
      disabled: isEvaluated(uiState),
    },
  });

  return (
    <div className="activity mc-activity">
      <div className="activity-content">
        <StemDelivery className="form-inline" stem={model.stem} context={writerContext} />
        <GradedPointsConnected />
        <ResetButtonConnected
          onReset={() =>
            dispatch(
              resetAction(
                onResetActivity,
                model.inputs.reduce((acc, input) => {
                  acc[input.partId] = [''];
                  return acc;
                }, {} as PartInputs),
              ),
            )
          }
        />
        <SubmitButtonConnected disabled={false} />
        {hintsShown.map((partId) => (
          <HintsDeliveryConnected
            key={partId}
            partId={partId}
            shouldShow={hintsShown.includes(partId)}
          />
        ))}
        <EvaluationConnected />
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
