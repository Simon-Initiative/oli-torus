import React from 'react';
import ReactDOM from 'react-dom';
import {
  AuthoringElement,
  AuthoringElementProps,
  AuthoringElementProvider,
  useAuthoringElementContext,
} from '../AuthoringElement';
import { Provider } from 'react-redux';
import { configureStore } from 'state/store';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { Manifest } from 'components/activities/types';
import { MultiInput, MultiInputSchema } from 'components/activities/multi_input/schema';
import { ReactEditor } from 'slate-react';
import { InputRef } from 'data/content/model';
import { Editor, Transforms } from 'slate';
import { QuestionTab } from 'components/activities/multi_input/sections/authoring/QuestionTab';
import { AnswerKeyTab } from 'components/activities/multi_input/sections/authoring/AnswerKeyTab';
import { HintsTab } from 'components/activities/multi_input/sections/authoring/HintsTab';
import { MultiInputStem } from 'components/activities/multi_input/sections/authoring/MultiInputStem';
import { getByUnsafe } from 'data/activities/model/utils1';

const store = configureStore();

const MultiInput = () => {
  const { dispatch, model } = useAuthoringElementContext<MultiInputSchema>();
  const [editor, setEditor] = React.useState<(ReactEditor & Editor) | undefined>();
  const [selectedInputRef, setSelectedInputRef] = React.useState<InputRef | undefined>(undefined);

  console.log('model', model);

  React.useEffect(() => {
    if (!editor || !selectedInputRef) return;
    Transforms.select(editor, ReactEditor.findPath(editor, selectedInputRef));
  }, [selectedInputRef]);

  const input = model.inputs.find((input) => input.id === selectedInputRef?.id);
  const index = model.inputs.findIndex((input) => input.id === selectedInputRef?.id);

  return (
    <>
      <MultiInputStem
        selectedInputRef={selectedInputRef}
        setSelectedInputRef={setSelectedInputRef}
        setEditor={setEditor}
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
          <ActivitySettings settings={[shuffleAnswerChoiceSetting(model, dispatch)]} />
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
          <MultiInput />
        </AuthoringElementProvider>
      </Provider>,
      mountPoint,
    );
  }
}
// eslint-disable-next-line
const manifest = require('./manifest.json') as Manifest;
window.customElements.define(manifest.authoring.element, MultiInputAuthoring);
