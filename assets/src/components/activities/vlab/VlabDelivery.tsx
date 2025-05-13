import React, { useEffect } from 'react';
import ReactDOM from 'react-dom';
import { Provider, useDispatch, useSelector } from 'react-redux';
import { DeliveryElement, DeliveryElementProps } from 'components/activities/DeliveryElement';
import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { Manifest, PartId } from 'components/activities/types';
import { VlabSchema } from 'components/activities/vlab/schema';
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
  resetAction,
  submit,
} from 'data/activities/DeliveryState';
import { getByUnsafe } from 'data/activities/model/utils';
import { safelySelectStringInputs } from 'data/activities/utils';
import { defaultWriterContext } from 'data/content/writers/context';
import { configureStore } from 'state/store';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { ScoreAsYouGoHeader } from '../common/ScoreAsYouGoHeader';
import { ScoreAsYouGoSubmitReset } from '../common/ScoreAsYouGoSubmitReset';
import { SubmitResetConnected } from '../common/delivery/SubmitReset';

export const VlabComponent: React.FC = () => {
  const {
    state: activityState,
    context,
    onSubmitActivity,
    onSaveActivity,
    onResetActivity,
    model,
  } = useDeliveryElementContext<VlabSchema>();

  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const [hintsShown, setHintsShown] = React.useState<PartId[]>([]);
  const dispatch = useDispatch();

  const onVlabChange = () => {
    // Get the selected flask XML and parse.

    // TODO: this will break when more than one instance of Vlab is present on a page
    const selectedFlaskXML = (
      document.getElementById('vlab_' + model.stem.id) as any
    ).contentWindow.getSelectedItem();
    const parser = new DOMParser();
    const selectedFlask = parser.parseFromString(selectedFlaskXML, 'application/xml');

    // Loop over the inputs, if an input is type vlabInput, update it's value based on XML.
    if (!selectedFlask.querySelector('parsererror')) {
      let value = '';
      model.inputs.forEach((input) => {
        if (input.inputType === 'vlabvalue') {
          // Move this mess to Utils?
          // value = vlabValueFromXML(input, selectedFlask);
          const param = input.parameter;
          const volume: number = parseFloat(
            selectedFlask.getElementsByTagName('flask')[0].getElementsByTagName('volume')[0]
              .textContent as string,
          );
          const speciesList = Array.from(
            selectedFlask.getElementsByTagName('flask')[0].getElementsByTagName('species'),
          );
          if (param === 'volume' || param === 'temp') {
            value = selectedFlask.getElementsByTagName('flask')[0].getElementsByTagName(param)[0]
              .textContent as any;
          } else if (param === 'pH') {
            speciesList.forEach((species) => {
              if (species.getElementsByTagName('id')[0].textContent === '1') {
                const hPlusMolarity: number =
                  parseFloat(species.getElementsByTagName('moles')[0].textContent as any) / volume;
                value = (-1 * Math.log10(hPlusMolarity)).toString();
              }
            });
          } else {
            speciesList.forEach((species) => {
              if (species.getElementsByTagName('id')[0].textContent === input.species) {
                if (param === 'molarity') {
                  value = (
                    parseFloat(species.getElementsByTagName('moles')[0].textContent as any) / volume
                  ).toString();
                } else if (param === 'concentration') {
                  value = (
                    parseFloat(species.getElementsByTagName('mass')[0].textContent as any) / volume
                  ).toString();
                } else {
                  value = species.getElementsByTagName(param)[0].textContent as any;
                }
              }
            });
          }
          dispatch(
            activityDeliverySlice.actions.setStudentInputForPart({
              partId: input.partId,
              studentInput: [value],
            }),
          );
        }
      });
    }
  };

  const emptyPartInputs = model.inputs.reduce((acc: any, input: any) => {
    acc[input.partId] = [''];
    return acc;
  }, {} as PartInputs);

  useEffect(() => {
    listenForParentSurveySubmit(context.surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(context.surveyId, dispatch, onResetActivity, emptyPartInputs);
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
    window.addEventListener('message', onVlabChange);
    return () => {
      window.removeEventListener('message', onVlabChange);
    };
  }, []);

  // First render initializes state
  if (!uiState.partState) {
    return null;
  }

  const toggleHints = (id: string) => {
    const input = getByUnsafe((uiState.model as VlabSchema).inputs, (x) => x.id === id);
    setHintsShown((hintsShown) =>
      hintsShown.includes(input.partId)
        ? hintsShown.filter((id) => id !== input.partId)
        : hintsShown.concat(input.partId),
    );
  };

  const inputs = new Map(
    (uiState.model as VlabSchema).inputs.map((input) => [
      input.id,
      {
        input:
          input.inputType === 'dropdown'
            ? {
                id: input.id,
                inputType: input.inputType,
                options: (uiState.model as VlabSchema).choices
                  .filter((c) => input.choiceIds.includes(c.id))
                  .map((choice) => ({
                    value: choice.id,
                    displayValue: toSimpleText(choice.content),
                  })),
              }
            : { id: input.id, inputType: input.inputType },
        value: (uiState.partState[input.partId]?.studentInput || [''])[0],
        hasHints: !context.graded && uiState.partState[input.partId].hasMoreHints,
      },
    ]),
  );

  const onChange = (id: string, value: string) => {
    const input = getByUnsafe((uiState.model as VlabSchema).inputs, (x) => x.id === id);

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

  const onVlabLoad = () => {
    if (model.assignmentSource === 'builtIn') {
      const assignment = model.assignmentPath;
      (document.getElementById('vlab_' + model.stem.id) as any).contentWindow.loadAssignment(
        assignment,
      );
    } else {
      const assignmentJSON = {
        assignment: JSON.parse(model.assignment),
        configuration: JSON.parse(model.configuration),
        reactions: JSON.parse(model.reactions),
        solutions: JSON.parse(model.solutions),
        species: JSON.parse(model.species),
        spectra: JSON.parse(model.spectra),
      };
      (document.getElementById('vlab_' + model.stem.id) as any).contentWindow.loadAssignmentJSON(
        assignmentJSON,
      );
    }
  };

  const writerContext = defaultWriterContext({
    sectionSlug: context.sectionSlug,
    bibParams: context.bibParams,
    graded: context.graded,
    inputRefContext: {
      toggleHints,
      onChange,
      onBlur: (_id: string) => true,
      onPressEnter: (_id: string) => true,
      // TODO: This 'as any' cast was necessary as the types do not align
      // Is the right fix for this to add 'input: MultiInputDelivery | VlabDelivery' to context.ts?
      inputs: inputs as any,
      disabled: isEvaluated(uiState),
    },
  });

  const submitReset =
    !uiState.activityContext.graded || uiState.activityContext.batchScoring ? (
      <SubmitResetConnected
        onReset={() => dispatch(resetAction(onResetActivity, emptyPartInputs))}
        submitDisabled={false}
      />
    ) : (
      <ScoreAsYouGoSubmitReset
        onSubmit={() => dispatch(submit(onSubmitActivity))}
        onReset={() => dispatch(resetAction(onResetActivity, undefined))}
      />
    );

  return (
    <div className="activity mc-activity">
      <div className="activity-content">
        <ScoreAsYouGoHeader />
        <iframe
          id={'vlab_' + (uiState.model as VlabSchema).stem.id}
          className="vlab-holder"
          src="/vlab/vlab.html"
          onLoad={onVlabLoad}
        />
        <StemDelivery
          className="form-inline"
          stem={(uiState.model as VlabSchema).stem}
          context={writerContext}
        />
        <GradedPointsConnected />

        {submitReset}

        {hintsShown.map((partId) => (
          <HintsDeliveryConnected
            key={partId}
            partId={partId}
            shouldShow={hintsShown.includes(partId)}
            resetPartInputs={emptyPartInputs}
          />
        ))}
        <EvaluationConnected />
      </div>
    </div>
  );
};

// Defines the web component, a simple wrapper over our React component above
export class VlabDelivery extends DeliveryElement<VlabSchema> {
  render(mountPoint: HTMLDivElement, props: DeliveryElementProps<VlabSchema>) {
    const store = configureStore({}, activityDeliverySlice.reducer, { name: 'VLabDelivery' });
    ReactDOM.render(
      <Provider store={store}>
        <DeliveryElementProvider {...props}>
          <VlabComponent />
        </DeliveryElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}

// Register the web component:
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.delivery.element, VlabDelivery);
