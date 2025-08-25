import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Maybe } from 'tsmonad';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { Choices as ChoicesAuthoring } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { TargetedFeedback } from 'components/activities/common/responses/TargetedFeedback';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { mcV1toV2 } from 'components/activities/multiple_choice/transformations/v2';
import { getCorrectChoice } from 'components/activities/multiple_choice/utils';
import { Radio } from 'components/misc/icons/radio/Radio';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Choices } from 'data/activities/model/choices';
import { defaultWriterContext } from 'data/content/writers/context';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { MCActions as Actions } from '../common/authoring/actions/multipleChoiceActions';
import { Explanation } from '../common/explanation/ExplanationAuthoring';
import { ActivityScoring } from '../common/responses/ActivityScoring';
import { TriggerAuthoring, TriggerLabel } from '../common/triggers/TriggerAuthoring';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';
import { StudentResponses } from '../common/responses/StudentResponses';
import { VegaLiteRenderer } from 'components/misc/VegaLiteRenderer';
import * as ActivityTypes from '../types';
import { MCSchema } from './schema';

const store = configureStore();

const ControlledTabs: React.FC<{ isInstructorPreview: boolean; children: React.ReactNode }> = ({
  isInstructorPreview,
  children
}) => {
  const [activeTab, setActiveTab] = React.useState<number>(0);

  // Force the first visible tab to be active when the mode changes
  React.useEffect(() => {
    setActiveTab(0);
  }, [isInstructorPreview]);

  const validChildren = React.Children.toArray(children).filter(
    (child): child is React.ReactElement => React.isValidElement(child)
  );

  return (
    <>
      <ul className="nav nav-tabs my-2 flex justify-between" role="tablist">
        {validChildren.map((child, index) => (
          <li key={'tab-' + index} className="nav-item" role="presentation">
            <button
              onClick={(e) => {
                e.preventDefault();
                e.stopPropagation();
                setActiveTab(index);
              }}
              className={'text-primary nav-link px-3' + (index === activeTab ? ' active' : '')}
              data-bs-toggle="tab"
              role="tab"
              aria-controls={'tab-' + index}
              aria-selected={index === activeTab}
            >
              {child.props.label}
            </button>
          </li>
        ))}
      </ul>
      <div className="tab-content">
        {validChildren.map((child, index) => (
          <div
            key={'tab-content-' + index}
            className={'tab-pane' + (index === activeTab ? ' show active' : '')}
            role="tabpanel"
            aria-labelledby={'tab-' + index}
          >
            {child.props.children}
          </div>
        ))}
      </div>
    </>
  );
};

const MultipleChoice: React.FC = () => {
  const { dispatch, model, editMode, mode, projectSlug, authoringContext, student_responses } =
    useAuthoringElementContext<MCSchema>();
  const writerContext = defaultWriterContext({
    projectSlug: projectSlug,
  });
  const isInstructorPreview = mode === 'instructor_preview';
  console.log("MCQ")
  console.log(model);
  return (
    <>
      <ControlledTabs isInstructorPreview={isInstructorPreview}>
        {isInstructorPreview && (
          <TabbedNavigation.Tab key="student-responses" label="Student Responses">
            <StudentResponses model={model} projectSlug={projectSlug}>
              {student_responses && student_responses[model.authoring.parts[0].id] && (
                <VegaLiteRenderer
                  spec={viz(student_responses[model.authoring.parts[0].id])}
                />
              )}
            </StudentResponses>
          </TabbedNavigation.Tab>
        )}

        {!isInstructorPreview && (
          <TabbedNavigation.Tab key="question" label="Question">
            <Stem />
            <ChoicesAuthoring
              icon={<Radio.Unchecked />}
              choices={model.choices}
              addOne={() => dispatch(Choices.addOne(ActivityTypes.makeChoice('')))}
              setAll={(choices: ActivityTypes.Choice[]) => dispatch(Choices.setAll(choices))}
              onEdit={(id, content) => dispatch(Choices.setContent(id, content))}
              onRemove={(id) => dispatch(Actions.removeChoice(id, model.authoring.parts[0].id))}
              onChangeEditorType={(id, editor) => dispatch(Choices.setEditor(id, editor))}
              onChangeEditorTextDirection={(id, textDirection) => {
                dispatch(Choices.setTextDirection(id, textDirection));
              }}
            />
          </TabbedNavigation.Tab>
        )}
        <TabbedNavigation.Tab label="Answer Key">
          <StemDelivery stem={model.stem} context={writerContext} />

          <ChoicesDelivery
            unselectedIcon={<Radio.Unchecked />}
            selectedIcon={<Radio.Checked />}
            choices={model.choices}
            selected={getCorrectChoice(model, model.authoring.parts[0].id).caseOf({
              just: (c) => [c.id],
              nothing: () => [],
            })}
            onSelect={(id) =>
              dispatch(Actions.toggleChoiceCorrectness(id, model.authoring.parts[0].id))
            }
            isEvaluated={false}
            context={writerContext}
            disabled={isInstructorPreview}
          />
          <SimpleFeedback partId={model.authoring.parts[0].id} />
          <ActivityScoring partId={model.authoring.parts[0].id} />

          <TargetedFeedback
            toggleChoice={(choiceId, mapping) => {
              dispatch(Actions.editTargetedFeedbackChoice(mapping.response.id, choiceId));
            }}
            addTargetedResponse={() =>
              dispatch(Actions.addTargetedFeedback(model.authoring.parts[0].id))
            }
            unselectedIcon={<Radio.Unchecked />}
            selectedIcon={<Radio.Checked />}
            disabled={isInstructorPreview}
          />
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Hints">
          <Hints partId={model.authoring.parts[0].id} />
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Explanation">
          <Explanation partId={model.authoring.parts[0].id} />
        </TabbedNavigation.Tab>

        <TabbedNavigation.Tab label="Dynamic Variables">
          <VariableEditorOrNot
            editMode={editMode}
            mode={mode}
            model={model}
            onEdit={(t) => dispatch(VariableActions.onUpdateTransformations(t))}
          />
        </TabbedNavigation.Tab>

        {authoringContext?.optionalContentTypes?.triggers && (
          <TabbedNavigation.Tab label={TriggerLabel()}>
            <TriggerAuthoring partId={model.authoring.parts[0].id} />
          </TabbedNavigation.Tab>
        )}

        <ActivitySettings settings={[shuffleAnswerChoiceSetting(model, dispatch)]} />
      </ControlledTabs>
    </>
  );
};

function viz(values: any) {
  return {
    "$schema": "https://vega.github.io/schema/vega-lite/v5.json",
    "title": { "text": "First Attempt", "fontSize": 16, "anchor": "start", "dy": -5 },
    "params": [
      {
        "name": "isDarkMode",
        "value": false
      }
    ],
    "data": {
      "values": values
    },
    "transform": [
      { "calculate": "datum.count + ' students'", "as": "countLabel" },
      { "calculate": "length(datum.count + ' students') * 6 + 6", "as": "checkOffset" }
    ],
    "height": { "step": 32 },
    "width": 330,
    "config": {
      "axis": { "labelFontSize": 13, "title": null, "grid": false, "ticks": false, "domain": false },
      "view": { "stroke": null }
    },
    "layer": [
      {
        "mark": { "type": "bar", "cornerRadiusEnd": 3, "height": 12 },
        "encoding": {
          "y": { "field": "label", "type": "nominal", "sort": null, "axis": { "labelPadding": 8 } },
          "x": { "field": "count", "type": "quantitative", "axis": null },
          "color": {
            "condition": { "test": "datum.correct", "value": "#27ae60" },
            "value": "#b23b2e"
          }
        }
      },
      {
        "mark": { "type": "text", "baseline": "middle", "align": "left", "dx": 6 },
        "encoding": {
          "y": { "field": "label", "type": "nominal" },
          "x": { "field": "count", "type": "quantitative" },
          "text": { "field": "countLabel" },
          "color": { "value": "#555555" }
        }
      },
      {
        "mark": { "type": "text", "baseline": "middle", "align": "left" },
        "encoding": {
          "y": { "field": "label", "type": "nominal" },
          "x": { "field": "count", "type": "quantitative" },
          "text": { "value": "✓" },
          "color": { "value": "#27ae60" },
          "opacity": { "condition": { "test": "datum.correct", "value": 1 }, "value": 0 },
          "xOffset": { "field": "checkOffset", "type": "quantitative" }
        }
      }
    ]
  } as any
}

export class MultipleChoiceAuthoring extends AuthoringElement<MCSchema> {
  migrateModelVersion(model: any): MCSchema {
    return Maybe.maybe(model.authoring.version).caseOf({
      just: (_v2) => model,
      nothing: () => mcV1toV2(model),
    });
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<MCSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <MultipleChoice />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, MultipleChoiceAuthoring);
