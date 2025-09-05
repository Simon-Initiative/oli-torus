import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
// import { VegaLite, VisualizationSpec } from 'react-vega';
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
import { ActivityScoring } from '../common/responses/ActivityScoring';
import { SimpleFeedback } from '../common/responses/SimpleFeedback';
import { StudentResponses as _StudentResponses } from '../common/responses/StudentResponses';
import { TargetedFeedback } from '../common/responses/TargetedFeedback';
import { StemDelivery } from '../common/stem/delivery/StemDelivery';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';
import * as ActivityTypes from '../types';
import { LikertActions } from './actions';
import { LikertModelSchema } from './schema';

const ControlledTabs: React.FC<{ isInstructorPreview: boolean; children: React.ReactNode }> = ({
  isInstructorPreview,
  children,
}) => {
  const [activeTab, setActiveTab] = React.useState<number>(0);

  // Force the first visible tab to be active when the mode changes
  React.useEffect(() => {
    setActiveTab(0);
  }, [isInstructorPreview]);

  const validChildren = React.Children.toArray(children).filter(
    (child): child is React.ReactElement => React.isValidElement(child),
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

const Likert = (props: AuthoringElementProps<LikertModelSchema>) => {
  const { dispatch, model, editMode, mode, projectSlug } =
    useAuthoringElementContext<LikertModelSchema>();

  // for now, we always select the first part for editing correct/feedback/hints.
  const selectedPartId = model.authoring.parts[0].id;
  const selectedItem = model.items.find((i) => i.id == selectedPartId) || model.items[0];
  const writerContext = defaultWriterContext({
    projectSlug: projectSlug,
  });
  const isInstructorPreview = mode === 'instructor_preview';

  // const transformedData = {
  //   values: model.choices
  //     .filter((choice) => choice.frequency > 0)
  //     .map((choice) => ({
  //       label:
  //         'text' in choice.content[0].children[0] ? choice.content[0].children[0].text : 'No text',
  //       value: choice.frequency,
  //     })),
  // };

  // const colorsList = [
  //   'rgb(198, 207, 241)',
  //   'rgb(220, 198, 224)',
  //   'rgb(202, 233, 198)',
  //   'rgb(209, 196, 233)',
  //   'rgb(160, 219, 206)',
  //   'rgb(242, 205, 176)',
  //   'rgb(187, 223, 179)',
  //   'rgb(231, 174, 125)',
  //   'rgb(187, 192, 206)',
  //   'rgb(241, 196, 198)',
  //   'rgb(194, 220, 232)',
  //   'rgb(236, 217, 203)',
  //   'rgb(172, 225, 240)',
  //   'rgb(247, 214, 199)',
  //   'rgb(207, 241, 206)',
  // ];

  // const spec: VisualizationSpec = {
  //   $schema: 'https://vega.github.io/schema/vega-lite/v5.json',
  //   data: transformedData,
  //   title: {
  //     text: model.activityTitle,
  //     subtitle: model.items.map((item) =>
  //       'text' in item.content[0].children[0] ? item.content[0].children[0].text : 'No text',
  //     ),
  //     subtitlePadding: 10,
  //   },
  //   mark: { type: 'bar' },
  //   width: 500,
  //   height: 200,
  //   encoding: {
  //     x: {
  //       aggregate: 'sum',
  //       field: 'value',
  //       type: 'quantitative',
  //       axis: { title: null },
  //     },
  //     y: {
  //       field: 'category',
  //       type: 'ordinal',
  //       axis: { title: null, labels: false },
  //     },
  //     color: {
  //       field: 'label',
  //       type: 'nominal',
  //       scale: {
  //         range: colorsList,
  //       },
  //     },
  //     tooltip: [
  //       { field: 'value', type: 'quantitative', title: 'Value' },
  //       { field: 'label', type: 'nominal', title: 'Text' },
  //     ],
  //   },
  //   config: {
  //     view: { stroke: 'transparent' },
  //     axisX: { labels: true },
  //     legend: {
  //       orient: 'right',
  //       title: null,
  //       padding: 10,
  //       rowPadding: 10,
  //     },
  //   },
  // };

  // const dataLong = transformedData.values.length;

  return (
    <React.Fragment>
      <ControlledTabs isInstructorPreview={isInstructorPreview}>
        <TabbedNavigation.Tab label="Question">
          <Stem />
          <div>
            <br />
            <p>Choices:</p>
            <div className="flex flex-col lg:flex-row">
              <div className="w-full">
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
            </div>
            {/* <div className="flex flex-col lg:flex-row">
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
                    <VegaLite spec={spec} />
                  </div>
                </>
              )}
            </div> */}
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
            disabled={isInstructorPreview}
          />
          <SimpleFeedback partId={selectedPartId} />
          <ActivityScoring partId={model.authoring.parts[0].id} />

          <TargetedFeedback
            toggleChoice={(choiceId, mapping) => {
              dispatch(MCActions.editTargetedFeedbackChoice(mapping.response.id, choiceId));
            }}
            addTargetedResponse={() =>
              dispatch(MCActions.addTargetedFeedback(model.authoring.parts[0].id))
            }
            unselectedIcon={<Radio.Unchecked />}
            selectedIcon={<Radio.Checked />}
            disabled={isInstructorPreview}
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
            mode={mode}
            model={model}
            onEdit={(t) => dispatch(VariableActions.onUpdateTransformations(t))}
          />
        </TabbedNavigation.Tab>
      </ControlledTabs>
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
