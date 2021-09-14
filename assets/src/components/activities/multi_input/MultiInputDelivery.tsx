import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { configureStore } from 'state/store';
import {
  ActivityDeliveryState,
  initializeState,
  activityDeliverySlice,
  resetAction,
  isEvaluated,
  PartInputs,
} from 'data/activities/DeliveryState';
import { safelySelectInputs } from 'data/activities/utils';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submit_button/SubmitButtonConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import {
  DeliveryElement,
  DeliveryElementProps,
  DeliveryElementProvider,
  useDeliveryElementContext,
} from 'components/activities/DeliveryElement';
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { Manifest } from 'components/activities/types';
import { defaultWriterContext } from 'data/content/writers/context';
import { getByUnsafe, getParts } from 'data/activities/model/utils1';
import { toSimpleText } from 'data/content/text';

export const MultiInputComponent: React.FC = () => {
  const {
    state: activityState,
    onSaveActivity,
    onResetActivity,
    model,
    sectionSlug,
  } = useDeliveryElementContext<MultiInputSchema>();
  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const dispatch = useDispatch();

  useEffect(() => {
    dispatch(
      initializeState(
        activityState,
        safelySelectInputs(activityState).caseOf({
          just: (inputs) => inputs,
          nothing: () =>
            getParts(model).reduce((acc, part) => {
              acc[part.id] = [''];
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

  const writerContext = defaultWriterContext({
    sectionSlug,
    inputRefContext: {
      onChange: (id, e) => {
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
      },
      inputs: new Map(
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
                        displayValue: toSimpleText({ children: choice.content.model }),
                      })),
                  }
                : { id: input.id, inputType: input.inputType },
            value: (uiState.partState[input.partId]?.studentInput || [''])[0],
          },
        ]),
      ),
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
                getParts(model).reduce((acc, part) => {
                  acc[part.id] = [''];
                  return acc;
                }, {} as PartInputs),
              ),
            )
          }
        />
        <SubmitButtonConnected disabled={false} />
        {/* <HintsDeliveryConnected /> */}
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
