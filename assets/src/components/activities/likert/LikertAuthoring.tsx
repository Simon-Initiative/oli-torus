import React from 'react';
import { Bar } from 'react-chartjs-2';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import {
  BarElement,
  CategoryScale,
  Chart as ChartJS,
  Legend,
  LinearScale,
  Title,
  Tooltip,
} from 'chart.js';
import { Choices as ChoicesAuthoring } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { getCorrectChoice } from 'components/activities/multiple_choice/utils';
import { Radio } from 'components/misc/icons/radio/Radio';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Choices, Items } from 'data/activities/model/choices';
import { defaultWriterContext } from 'data/content/writers/context';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { MCActions } from '../common/authoring/actions/multipleChoiceActions';
import { ChoicesDelivery } from '../common/choices/delivery/ChoicesDelivery';
import { Explanation } from '../common/explanation/ExplanationAuthoring';
import { SimpleFeedback } from '../common/responses/SimpleFeedback';
import { TargetedFeedback } from '../common/responses/TargetedFeedback';
import { StemDelivery } from '../common/stem/delivery/StemDelivery';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';
import * as ActivityTypes from '../types';
import { LikertActions } from './actions';
import { LikertModelSchema } from './schema';

const Likert = (props: AuthoringElementProps<LikertModelSchema>) => {
  const { dispatch, model, editMode, projectSlug } =
    useAuthoringElementContext<LikertModelSchema>();

  // for now, we always select the first part for editing correct/feedback/hints.
  const selectedPartId = model.authoring.parts[0].id;
  const selectedItem = model.items.find((i) => i.id == selectedPartId) || model.items[0];
  const writerContext = defaultWriterContext({
    projectSlug: projectSlug,
  });

  ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend);

  const likertChartOptions = {
    plugins: {
      title: {
        display: true,
        text: model.activityTitle,
      },
    },
    indexAxis: 'y' as 'y' | 'x' | undefined,
    responsive: true,
    scales: {
      x: {
        stacked: true,
      },
      y: {
        stacked: true,
      },
    },
  };

  function getRandomPastelColor() {
    const min = 130;
    const max = 255;

    const r = Math.floor(Math.random() * (max - min + 1) + min);
    const g = Math.floor(Math.random() * (max - min + 1) + min);
    const b = Math.floor(Math.random() * (max - min + 1) + min);

    return `rgb(${r}, ${g}, ${b})`;
  }

  const dataToRender = {
    labels: model.items.map((item) =>
      'text' in item.content[0].children[0] ? item.content[0].children[0].text : 'No text',
    ),
    datasets: model.choices
      .filter((choice) => choice.frequency > 0)
      .map((choice) => ({
        label:
          'text' in choice.content[0].children[0] ? choice.content[0].children[0].text : 'No text',
        data: [choice.frequency],
        backgroundColor: getRandomPastelColor(),
      })),
  };

  const dataLong = dataToRender.datasets.length;

  return (
    <React.Fragment>
      <TabbedNavigation.Tabs>
        <TabbedNavigation.Tab label="Question">
          <Stem />
          <div>
            <br />
            <p>Choices:</p>
            <div className="flex flex-col lg:flex-row">
              <div className={`${dataLong > 0 ? 'w-full lg:w-1/2' : 'w-full'}`}>
                <ChoicesAuthoring
                  icon={<Radio.Unchecked />}
                  choices={model.choices}
                  setAll={(choices: ActivityTypes.Choice[]) => dispatch(Choices.setAll(choices))}
                  onEdit={(id, content) => dispatch(Choices.setContent(id, content))}
                  onChangeEditorType={(id, editorType) =>
                    dispatch(Choices.setEditor(id, editorType))
                  }
                  addOne={() => dispatch(LikertActions.addChoice())}
                  onRemove={(id) => dispatch(LikertActions.removeChoice(id))}
                  onChangeEditorTextDirection={(id, textDirection) =>
                    dispatch(Choices.setTextDirection(id, textDirection))
                  }
                />
              </div>
              {dataLong > 0 && (
                <>
                  <div className="hidden lg:flex border-r border-2 border-gray-500 mx-4" />
                  <div
                    className={`${dataLong > 0 && 'flex items-center w-full my-5 lg:w-1/2 px-2'}`}
                  >
                    <Bar options={likertChartOptions} data={dataToRender} />
                  </div>
                </>
              )}
            </div>
            <div className="form-check mb-2">
              <input
                className="form-check-input"
                type="checkbox"
                id="descending-toggle"
                aria-label="Checkbox for descending order"
                checked={model.orderDescending}
                onChange={(e: any) => dispatch(LikertActions.setOrderDescending(e.target.checked))}
              />
              <label className="form-check-label" htmlFor="descending-toggle">
                Number Descending
              </label>
            </div>
          </div>

          <p>Questions:</p>
          <ChoicesAuthoring
            choices={model.items}
            setAll={(choices: ActivityTypes.Choice[]) => dispatch(Items.setAll(choices))}
            onEdit={(id, content) => dispatch(Items.setContent(id, content))}
            onChangeEditorType={(id, editorType) => dispatch(Items.setEditor(id, editorType))}
            addOne={() => dispatch(LikertActions.addItem())}
            onRemove={(id) => dispatch(LikertActions.removeItem(id))}
            onChangeEditorTextDirection={(id, textDirection) =>
              dispatch(Items.setTextDirection(id, textDirection))
            }
          />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <StemDelivery stem={selectedItem} context={writerContext} />

          <ChoicesDelivery
            unselectedIcon={<Radio.Unchecked />}
            selectedIcon={<Radio.Checked />}
            choices={model.choices}
            selected={getCorrectChoice(model, selectedPartId).caseOf({
              just: (choice) => [choice.id],
              nothing: () => [],
            })}
            onSelect={(id) => dispatch(MCActions.toggleChoiceCorrectness(id, selectedPartId))}
            isEvaluated={false}
            context={writerContext}
          />
          <SimpleFeedback partId={selectedPartId} />
          <TargetedFeedback
            toggleChoice={(choiceId, mapping) => {
              dispatch(MCActions.editTargetedFeedbackChoice(mapping.response.id, choiceId));
            }}
            addTargetedResponse={() =>
              dispatch(MCActions.addTargetedFeedback(model.authoring.parts[0].id))
            }
            unselectedIcon={<Radio.Unchecked />}
            selectedIcon={<Radio.Checked />}
          />
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <Hints partId={selectedPartId} />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Explanation">
          <Explanation partId={selectedPartId} />
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Dynamic Variables">
          <VariableEditorOrNot
            editMode={editMode}
            model={model}
            onEdit={(t) => dispatch(VariableActions.onUpdateTransformations(t))}
          />
        </TabbedNavigation.Tab>
      </TabbedNavigation.Tabs>
    </React.Fragment>
  );
};

const store = configureStore();

export class LikertAuthoring extends AuthoringElement<LikertModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<LikertModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <Likert {...props} />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, LikertAuthoring);
