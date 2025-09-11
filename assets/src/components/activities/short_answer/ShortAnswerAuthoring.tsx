import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { AuthoringButtonConnected } from 'components/activities/common/authoring/AuthoringButton';
import { GradingApproachDropdown } from 'components/activities/common/authoring/GradingApproachDropdown';
import { InputTypeDropdown } from 'components/activities/common/authoring/InputTypeDropdown';
import { Hints } from 'components/activities/common/hints/authoring/HintsAuthoringConnected';
import { ResponseCard } from 'components/activities/common/responses/ResponseCard';
import { SimpleFeedback } from 'components/activities/common/responses/SimpleFeedback';
import { ResponseActions } from 'components/activities/common/responses/responseActions';
import { Stem } from 'components/activities/common/stem/authoring/StemAuthoringConnected';
import { StemDelivery } from 'components/activities/common/stem/delivery/StemDelivery';
import { InputEntry } from 'components/activities/short_answer/sections/InputEntry';
import { getTargetedResponses, shortAnswerOptions } from 'components/activities/short_answer/utils';
import {
  GradingApproach,
  HasParts,
  Manifest,
  Response,
  RichText,
  makeResponse,
} from 'components/activities/types';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import {
  Responses,
  getCorrectResponse,
  getIncorrectResponse,
  hasCustomScoring,
} from 'data/activities/model/responses';
import { containsRule, eqRule } from 'data/activities/model/rules';
import { defaultWriterContext } from 'data/content/writers/context';
import { configureStore } from 'state/store';
import { clone } from 'utils/common';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { RespondedUsersList } from '../common/authoring/RespondedUsersList';
import { ActivitySettings } from '../common/authoring/settings/ActivitySettings';
import { Explanation } from '../common/explanation/ExplanationAuthoring';
import { ActivityScoring } from '../common/responses/ActivityScoring';
import { StudentResponses as _StudentResponses } from '../common/responses/StudentResponses';
import { TriggerAuthoring, TriggerLabel } from '../common/triggers/TriggerAuthoring';
import { toggleSubmitAndCompareOption } from '../common/utils';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';
import { ShortAnswerActions } from './actions';
import { ShortAnswerModelSchema } from './schema';

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

const ShortAnswer = () => {
  const { dispatch, model, editMode, mode, projectSlug, authoringContext } =
    useAuthoringElementContext<ShortAnswerModelSchema>();
  const isInstructorPreview = mode === 'instructor_preview';

  const submitAndCompareSetting = {
    label: 'Submit And Compare',
    isEnabled: model.submitAndCompare === true,
    onToggle: () => dispatch(toggleSubmitAndCompareOption()),
  };

  return (
    <>
      <ControlledTabs isInstructorPreview={isInstructorPreview}>
        <TabbedNavigation.Tab label="Question">
          <div className="d-flex flex-column flex-md-row mb-2">
            <Stem />
            {!model.responses ? (
              <InputTypeDropdown
                options={shortAnswerOptions}
                editMode={editMode}
                selected={model.inputType}
                onChange={(inputType) =>
                  dispatch(ShortAnswerActions.setInputType(inputType, model.authoring.parts[0].id))
                }
              />
            ) : (
              <table>
                <tr>
                  <th>Students</th>
                  <th>Response</th>
                </tr>
                <tbody>
                  {model.responses.map((response, index) => (
                    <tr key={index}>
                      <td className="whitespace-nowrap">
                        <RespondedUsersList users={response.users} />
                      </td>
                      <td>{response.text}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </TabbedNavigation.Tab>
        <TabbedNavigation.Tab label="Answer Key">
          <div className="d-flex flex-column mb-2">
            <StemDelivery
              stem={model.stem}
              context={defaultWriterContext({ projectSlug: projectSlug })}
            />
            <GradingApproachDropdown
              editMode={editMode}
              selected={
                model.authoring.parts[0].gradingApproach === undefined
                  ? GradingApproach.automatic
                  : model.authoring.parts[0].gradingApproach
              }
              onChange={(gradingApproach) =>
                dispatch(
                  ShortAnswerActions.setGradingApproach(
                    gradingApproach,
                    model.authoring.parts[0].id,
                  ),
                )
              }
            />
            <InputEntry
              key={getCorrectResponse(model, model.authoring.parts[0].id).id}
              inputType={model.inputType}
              response={getCorrectResponse(model, model.authoring.parts[0].id)}
              onEditResponseRule={(id, rule) => dispatch(ResponseActions.editRule(id, rule))}
            />
            <SimpleFeedback partId={model.authoring.parts[0].id} />
            <ActivityScoring partId={model.authoring.parts[0].id} />
            {getTargetedResponses(model, model.authoring.parts[0].id).map((response: Response) => (
              <ResponseCard
                title="Targeted feedback"
                response={response}
                customScoring={hasCustomScoring(model, model.authoring.parts[0].id)}
                updateScore={(_id, score) =>
                  dispatch(ResponseActions.editResponseScore(response.id, score))
                }
                updateFeedbackEditor={(_id, editor) =>
                  dispatch(ResponseActions.editResponseFeedbackEditor(response.id, editor))
                }
                updateFeedbackTextDirection={(_id, textDirection) =>
                  dispatch(
                    ResponseActions.editResponseFeedbackTextDirection(response.id, textDirection),
                  )
                }
                updateFeedback={(_id, content) =>
                  dispatch(ResponseActions.editResponseFeedback(response.id, content as RichText))
                }
                updateCorrectness={(_id, correct) =>
                  dispatch(ResponseActions.editResponseCorrectness(response.id, correct))
                }
                removeResponse={(id) => dispatch(ResponseActions.removeResponse(id))}
                key={response.id}
              >
                <InputEntry
                  key={response.id}
                  inputType={model.inputType}
                  response={response}
                  onEditResponseRule={(id, rule) => dispatch(ResponseActions.editRule(id, rule))}
                />
              </ResponseCard>
            ))}
            <AuthoringButtonConnected
              className="self-start btn btn-link"
              action={() =>
                dispatch(
                  ResponseActions.addResponse(
                    makeResponse(
                      model.inputType === 'numeric' ? eqRule(1) : containsRule('another answer'),
                      0,
                      '',
                    ),
                    model.authoring.parts[0].id,
                  ),
                )
              }
            >
              Add targeted feedback
            </AuthoringButtonConnected>
          </div>
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

        <ActivitySettings settings={[submitAndCompareSetting]} />
      </ControlledTabs>
    </>
  );
};

const ensureCatchAll = (model: HasParts) => {
  try {
    // eslint-disable-next-line @typescript-eslint/no-unused-expressions
    getIncorrectResponse(model, model.authoring.parts[0].id);
    return model;
  } catch (ex) {
    const newModel = clone(model);
    newModel.authoring.parts[0].responses.push(Responses.catchAll());
    return newModel;
  }
};

export class ShortAnswerAuthoring extends AuthoringElement<ShortAnswerModelSchema> {
  migrateModelVersion(model: ShortAnswerModelSchema) {
    // Some questions desiring legacy submit and compare behavior (no incorrect answer)
    // may have wound up with .* as correct response rule and no catch-all.
    // But authoring requires a catchAll, so add one to model if needed
    return ensureCatchAll(model) as ShortAnswerModelSchema;
  }

  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<ShortAnswerModelSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <ShortAnswer />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.authoring.element, ShortAnswerAuthoring);
