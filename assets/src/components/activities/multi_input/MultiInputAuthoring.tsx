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
import { MultiInputSchema } from 'components/activities/multi_input/schema';
import { AnswerKeyTab } from 'components/activities/multi_input/sections/AnswerKeyTab';
import { HintsTab } from 'components/activities/multi_input/sections/HintsTab';
import { MultiInputStem } from 'components/activities/multi_input/sections/MultiInputStem';
import { QuestionTab } from 'components/activities/multi_input/sections/QuestionTab';
import { Manifest } from 'components/activities/types';
import { elementsOfType } from 'components/editing/slateUtils';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { InputRef } from 'data/content/model/elements/types';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { AuthoringElementProvider, useAuthoringElementContext } from '../AuthoringElementProvider';
import { TriggerAuthoring, TriggerLabel } from '../common/triggers/TriggerAuthoring';
import { VariableEditorOrNot } from '../common/variables/VariableEditorOrNot';
import { VariableActions } from '../common/variables/variableActions';
import { ExplanationTab } from './sections/ExplanationTab';

const store = configureStore();

export const MultiInputComponent = () => {
  const { dispatch, model, editMode } = useAuthoringElementContext<MultiInputSchema>();
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

  const settings = [
    shuffleAnswerChoiceSetting(model, dispatch, input),
    changePerPartSubmission(model, dispatch),
  ];

  return (
    <>
      <MultiInputStem
        selectedInputRef={selectedInputRef}
        setSelectedInputRef={setSelectedInputRef}
        setEditor={setEditor}
        isMultiInput={true}
      />
      {editor && input ? (
        <TabbedNavigation.Tabs>
          <TabbedNavigation.Tab label="Question">
            <QuestionTab editor={editor} input={input} index={index} />
          </TabbedNavigation.Tab>
          <TabbedNavigation.Tab label="Answer Key">
            <AnswerKeyTab input={input} />
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
          <TabbedNavigation.Tab label={TriggerLabel()}>
            <TriggerAuthoring partId={input.partId} />
          </TabbedNavigation.Tab>

          <ActivitySettings settings={settings} />
        </TabbedNavigation.Tabs>
      ) : (
        'Select an input to edit it'
      )}
    </>
  );
};

export class MultiInputAuthoring extends AuthoringElement<MultiInputSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<MultiInputSchema>) {
    ReactDOM.render(
      <Provider store={store}>
        <AuthoringElementProvider {...props}>
          <MultiInputComponent />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.authoring.element, MultiInputAuthoring);
