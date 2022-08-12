import { EvaluationConnected } from 'components/activities/common/delivery/evaluation/EvaluationConnected';
import { GradedPointsConnected } from 'components/activities/common/delivery/graded_points/GradedPointsConnected';
import { ResetButtonConnected } from 'components/activities/common/delivery/reset_button/ResetButtonConnected';
import { SubmitButtonConnected } from 'components/activities/common/delivery/submit_button/SubmitButtonConnected';
import { HintsDeliveryConnected } from 'components/activities/common/hints/delivery/HintsDeliveryConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { DeliveryElement, DeliveryElementProps } from 'components/activities/DeliveryElement';
import { DeliveryElementProvider, useDeliveryElementContext } from '../DeliveryElementProvider';
import { MultiInputSchema } from 'components/activities/vlab/schema';
import { Manifest, PartId } from 'components/activities/types';
import { toSimpleText } from 'components/editing/slateUtils';
import {
  activityDeliverySlice,
  ActivityDeliveryState,
  initializeState,
  isEvaluated,
  listenForParentSurveySubmit,
  listenForParentSurveyReset,
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
    surveyId,
    sectionSlug,
    bibParams,
    onSubmitActivity,
    onSaveActivity,
    onResetActivity,
    model,
  } = useDeliveryElementContext<MultiInputSchema>();

  const uiState = useSelector((state: ActivityDeliveryState) => state);
  const [hintsShown, setHintsShown] = React.useState<PartId[]>([]);
  const dispatch = useDispatch();

  const onVlabChange = () => {
    // Get the selected flask XML and parse.
    const selectedFlaskXML = document.getElementById('vlab').contentWindow.getSelectedItem();
    const parser = new DOMParser();
    const selectedFlask = parser.parseFromString(selectedFlaskXML, 'application/xml');

    // Loop over the inputs, if an input is type vlabInput, update it's value based on XML.
    if (!selectedFlask.querySelector('parsererror')) {
      let value = 0;
      model.inputs.forEach((input) => {
        if (input.inputType === 'vlabvalue') {
          // Move this mess to Utils?
          // value = vlabValueFromXML(input, selectedFlask);
          const param = input.parameter;
          const volume = selectedFlask
            .getElementsByTagName('flask')[0]
            .getElementsByTagName('volume')[0].textContent;
          const speciesList = Array.from(
            selectedFlask.getElementsByTagName('flask')[0].getElementsByTagName('species'),
          );
          if (param === 'volume' || param === 'temp') {
            value = selectedFlask
              .getElementsByTagName('flask')[0]
              .getElementsByTagName(param)[0].textContent;
          } else if (param === 'pH') {
            speciesList.forEach((species) => {
              if (species.getElementsByTagName('id')[0].textContent === '1') {
                const hPlusMolarity = species.getElementsByTagName('moles')[0].textContent / volume;
                value = -1 * Math.log10(hPlusMolarity);
              }
            });
          } else {
            speciesList.forEach((species) => {
              if (species.getElementsByTagName('id')[0].textContent === input.species) {
                if (param === 'molarity') {
                  value = species.getElementsByTagName('moles')[0].textContent / volume;
                } else if (param === 'concentration') {
                  value = species.getElementsByTagName('mass')[0].textContent / volume;
                } else {
                  value = species.getElementsByTagName(param)[0].textContent;
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
    listenForParentSurveySubmit(surveyId, dispatch, onSubmitActivity);
    listenForParentSurveyReset(surveyId, dispatch, onResetActivity, emptyPartInputs);

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

  const onChange = (id: string, e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const input = getByUnsafe((uiState.model as MultiInputSchema).inputs, (x) => x.id === id);
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

  const onVlabLoad = () => {
    if (model.assignmentSource === 'builtIn') {
      const assignment = model.assignmentPath;
      document.getElementById('vlab').contentWindow.loadAssignment(assignment);
    } else {
      const assignmentJSON = {
        assignment: JSON.parse(model.assignment),
        configuration: JSON.parse(model.configuration),
        reactions: JSON.parse(model.reactions),
        solutions: JSON.parse(model.solutions),
        species: JSON.parse(model.species),
        spectra: JSON.parse(model.spectra),
      };
      document.getElementById('vlab').contentWindow.loadAssignmentJSON(assignmentJSON);
    }
  };

  const writerContext = defaultWriterContext({
    sectionSlug,
    bibParams,
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
        <iframe id="vlab" className="vlab-holder" src="/vlab/vlab.html" onLoad={onVlabLoad} />
        <StemDelivery
          className="form-inline"
          stem={(uiState.model as MultiInputSchema).stem}
          context={writerContext}
        />
        <GradedPointsConnected />
        <ResetButtonConnected
          onReset={() => dispatch(resetAction(onResetActivity, emptyPartInputs))}
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
export class VlabDelivery extends DeliveryElement<MultiInputSchema> {
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
window.customElements.define(manifest.delivery.element, VlabDelivery);
