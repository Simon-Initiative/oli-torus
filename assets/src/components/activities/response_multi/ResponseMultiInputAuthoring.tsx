import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Editor, Transforms } from 'slate';
import { ReactEditor } from 'slate-react';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import {
  changePerPartSubmission,
  shuffleAnswerChoiceSetting,
} from 'components/activities/common/authoring/settings/activitySettingsActions';
import { ResponseMultiInputSchema } from 'components/activities/response_multi/schema';
import { HintsTab } from 'components/activities/response_multi/sections/HintsTab';
import { QuestionTab } from 'components/activities/response_multi/sections/QuestionTab';
import { ResponseMultiInputStem } from 'components/activities/response_multi/sections/ResponseMultiInputStem';
import { Manifest } from 'components/activities/types';
import { elementsOfType } from 'components/editing/slateUtils';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { getPartById } from 'data/activities/model/utils';
import { InputRef } from 'data/content/model/elements/types';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { TriggerAuthoring, TriggerLabel } from '../common/triggers/TriggerAuthoring';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';
import { StudentResponses } from '../common/responses/StudentResponses';
import { ExplanationTab } from './sections/ExplanationTab';
import { PartsTab } from './sections/PartsTab';

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

export const ResponseMultiInputComponent = () => {
  const { dispatch, model, editMode, mode, authoringContext } =
    useAuthoringElementContext<ResponseMultiInputSchema>();
  const [editor, setEditor] = React.useState<(ReactEditor & Editor) | undefined>();
  const [selectedInputRef, setSelectedInputRef] = React.useState<InputRef | undefined>(undefined);

  // Focus the active input ref selection when it changes
  React.useEffect(() => {
    if (!editor || !selectedInputRef) return;
    Transforms.select(editor, ReactEditor.findPath(editor, selectedInputRef));
  }, [selectedInputRef]);

  // Select the first input ref if none are selected
  React.useEffect(() => {
    if (!selectedInputRef && editor) {
      setSelectedInputRef(() => elementsOfType<InputRef>(editor, 'input_ref')[0]);
    }
  }, [editor]);

  const input = model.inputs.find((input) => input.id === selectedInputRef?.id);
  const index = model.inputs.findIndex((input) => input.id === selectedInputRef?.id);
  const isInstructorPreview = mode === 'instructor_preview';
  let refsTargeted: string[] | undefined;
  if (input) refsTargeted = getPartById(model, input.partId).targets;

  return (
    <>
      <ResponseMultiInputStem
        selectedInputRef={selectedInputRef}
        setSelectedInputRef={setSelectedInputRef}
        setEditor={setEditor}
        isResponseMultiInput={true}
        refsTargeted={refsTargeted}
      />
      {editor && input ? (
        <ControlledTabs isInstructorPreview={isInstructorPreview}>
          {mode === 'instructor_preview' && (
            <TabbedNavigation.Tab label="Student Responses">
              <StudentResponses model={model} />
            </TabbedNavigation.Tab>
          )}

          {!isInstructorPreview && (
            <TabbedNavigation.Tab label="Input">
              <QuestionTab editor={editor} input={input} index={index} />
            </TabbedNavigation.Tab>
          )}
          <TabbedNavigation.Tab label="Answer Key">
            <PartsTab editor={editor} input={input} index={index} />
          </TabbedNavigation.Tab>
          <TabbedNavigation.Tab label="Hints">
            <HintsTab input={input} index={index} />
          </TabbedNavigation.Tab>
          <TabbedNavigation.Tab label="Explanation">
            <ExplanationTab input={input} />
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
              <TriggerAuthoring partId={input.partId} />
            </TabbedNavigation.Tab>
          )}

          <ActivitySettings
            settings={[
              shuffleAnswerChoiceSetting(model, dispatch, input),
              changePerPartSubmission(model, dispatch),
            ]}
          />
        </ControlledTabs>
      ) : (
        'Select an input to edit it'
      )}
    </>
  );
};

export class ResponseMultiInputAuthoring extends AuthoringElement<ResponseMultiInputSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<ResponseMultiInputSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <ResponseMultiInputComponent />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.authoring.element, ResponseMultiInputAuthoring);
