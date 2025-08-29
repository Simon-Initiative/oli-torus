import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Maybe } from 'tsmonad';
import { CATASchema } from 'components/activities/check_all_that_apply/schema';
import { cataV1toV2 } from 'components/activities/check_all_that_apply/transformations/v2';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { Choices as ChoicesAuthoring } from 'components/activities/common/choices/authoring/ChoicesAuthoring';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { Hints as HintsAuthoring } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { TargetedFeedback } from 'components/activities/common/responses/TargetedFeedback';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { VegaLiteRenderer } from 'components/misc/VegaLiteRenderer';
import { Checkbox } from 'components/misc/icons/checkbox/Checkbox';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { Choices } from 'data/activities/model/choices';
import { getCorrectChoiceIds } from 'data/activities/model/responses';
import { defaultWriterContext } from 'data/content/writers/context';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { Explanation } from '../common/explanation/ExplanationAuthoring';
import { ActivityScoring } from '../common/responses/ActivityScoring';
import { StudentResponses } from '../common/responses/StudentResponses';
import { TriggerAuthoring, TriggerLabel } from '../common/triggers/TriggerAuthoring';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';
import * as ActivityTypes from '../types';
import { CATAActions } from './actions';
import studentResponsesSpec from './studentResponses.json';

const store = configureStore();

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

function viz(values: any) {
  // values, find the max count to create [0, < max >] for scale and domain
  const maxCount = Math.max(...values.map((v: any) => v.count), 0);
  const domain = [0, maxCount];

  const viz = {
    ...studentResponsesSpec,
    data: {
      values: values,
    },
  } as any;

  viz.layer[0].encoding.x.scale.domain = domain;
  viz.layer[0].encoding.x.axis.values = domain;

  return viz;
}

const CheckAllThatApply = () => {
  const { dispatch, model, editMode, mode, projectSlug, authoringContext, student_responses } =
    useAuthoringElementContext<CATASchema>();
  const writerContext = defaultWriterContext({
    projectSlug: projectSlug,
  });
  const isInstructorPreview = mode === 'instructor_preview';

  return (
    <ControlledTabs isInstructorPreview={isInstructorPreview}>
      {isInstructorPreview && (
        <TabbedNavigation.Tab key="student-responses" label="Student Responses">
          <StudentResponses model={model} projectSlug={projectSlug}>
            {student_responses && student_responses[model.authoring.parts[0].id] && (
              <VegaLiteRenderer spec={viz(student_responses[model.authoring.parts[0].id])} />
            )}
          </StudentResponses>
        </TabbedNavigation.Tab>
      )}

      {!isInstructorPreview && (
        <TabbedNavigation.Tab label="Question">
          <Stem />
          <ChoicesAuthoring
            icon={<Checkbox.Unchecked />}
            choices={model.choices}
            addOne={() => dispatch(CATAActions.addChoice(ActivityTypes.makeChoice('')))}
            setAll={(choices: ActivityTypes.Choice[]) => dispatch(Choices.setAll(choices))}
            onEdit={(id, content) => dispatch(Choices.setContent(id, content))}
            onChangeEditorType={(id, editorType) => dispatch(Choices.setEditor(id, editorType))}
            onRemove={(id) => dispatch(CATAActions.removeChoiceAndUpdateRules(id))}
            onChangeEditorTextDirection={(id, dir) => dispatch(Choices.setTextDirection(id, dir))}
          />
        </TabbedNavigation.Tab>
      )}

      <TabbedNavigation.Tab label="Answer Key">
        <StemDelivery stem={model.stem} context={writerContext} />

        <ChoicesDelivery
          unselectedIcon={<Checkbox.Unchecked />}
          selectedIcon={<Checkbox.Checked />}
          choices={model.choices}
          selected={getCorrectChoiceIds(model)}
          onSelect={(id) => dispatch(CATAActions.toggleChoiceCorrectness(id))}
          isEvaluated={false}
          context={writerContext}
          disabled={isInstructorPreview}
        />
        <SimpleFeedback partId={model.authoring.parts[0].id} />
        <ActivityScoring partId={model.authoring.parts[0].id} />

        <TargetedFeedback
          toggleChoice={(choiceId, mapping) => {
            dispatch(
              CATAActions.editTargetedFeedbackChoices(
                mapping.response.id,
                mapping.choiceIds.includes(choiceId)
                  ? mapping.choiceIds.filter((id) => id !== choiceId)
                  : mapping.choiceIds.concat(choiceId),
              ),
            );
          }}
          addTargetedResponse={() => dispatch(CATAActions.addTargetedFeedback())}
          unselectedIcon={<Checkbox.Unchecked />}
          selectedIcon={<Checkbox.Checked />}
          disabled={isInstructorPreview}
        />
      </TabbedNavigation.Tab>

      <TabbedNavigation.Tab label="Hints">
        <HintsAuthoring partId={model.authoring.parts[0].id} />
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
  );
};

export class CheckAllThatApplyAuthoring extends AuthoringElement<CATASchema> {
  migrateModelVersion(model: any): CATASchema {
    return Maybe.maybe(model.authoring.version).caseOf({
      just: (_v2) => model,
      nothing: () => cataV1toV2(model),
    });
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<CATASchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <CheckAllThatApply />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, CheckAllThatApplyAuthoring);
