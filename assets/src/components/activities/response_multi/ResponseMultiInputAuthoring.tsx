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
import { ExplanationTab } from './sections/ExplanationTab';
import { PartsTab } from './sections/PartsTab';

const store = configureStore();

export const ResponseMultiInputComponent = () => {
  const { dispatch, model, editMode, authoringContext } =
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
        <TabbedNavigation.Tabs>
          <TabbedNavigation.Tab label="Input">
            <QuestionTab editor={editor} input={input} index={index} />
          </TabbedNavigation.Tab>
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
        </TabbedNavigation.Tabs>
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
