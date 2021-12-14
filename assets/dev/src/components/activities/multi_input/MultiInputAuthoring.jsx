import { ActivitySettings } from 'components/activities/common/authoring/settings/ActivitySettings';
import { shuffleAnswerChoiceSetting } from 'components/activities/common/authoring/settings/activitySettingsActions';
import { AnswerKeyTab } from 'components/activities/multi_input/sections/AnswerKeyTab';
import { HintsTab } from 'components/activities/multi_input/sections/HintsTab';
import { MultiInputStem } from 'components/activities/multi_input/sections/MultiInputStem';
import { QuestionTab } from 'components/activities/multi_input/sections/QuestionTab';
import { elementsOfType } from 'components/editing/utils';
import { TabbedNavigation } from 'components/tabbed_navigation/Tabs';
import React from 'react';
import ReactDOM from 'react-dom';
import { Provider } from 'react-redux';
import { Transforms } from 'slate';
import { ReactEditor } from 'slate-react';
import { configureStore } from 'state/store';
import { AuthoringElement, AuthoringElementProvider, useAuthoringElementContext, } from '../AuthoringElement';
const store = configureStore();
export const MultiInputComponent = () => {
    const { dispatch, model } = useAuthoringElementContext();
    const [editor, setEditor] = React.useState();
    const [selectedInputRef, setSelectedInputRef] = React.useState(undefined);
    // Focus the active input ref selection when it changes
    React.useEffect(() => {
        if (!editor || !selectedInputRef)
            return;
        Transforms.select(editor, ReactEditor.findPath(editor, selectedInputRef));
    }, [selectedInputRef]);
    // Select the first input ref if none are selected
    React.useEffect(() => {
        if (!selectedInputRef && editor) {
            setSelectedInputRef(() => elementsOfType(editor, 'input_ref')[0]);
        }
    }, [editor]);
    const input = model.inputs.find((input) => input.id === (selectedInputRef === null || selectedInputRef === void 0 ? void 0 : selectedInputRef.id));
    const index = model.inputs.findIndex((input) => input.id === (selectedInputRef === null || selectedInputRef === void 0 ? void 0 : selectedInputRef.id));
    return (<>
      <MultiInputStem selectedInputRef={selectedInputRef} setSelectedInputRef={setSelectedInputRef} setEditor={setEditor}/>
      {editor && input ? (<TabbedNavigation.Tabs>
          <TabbedNavigation.Tab label="Question">
            <QuestionTab editor={editor} input={input} index={index}/>
          </TabbedNavigation.Tab>
          <TabbedNavigation.Tab label="Answer Key">
            <AnswerKeyTab input={input}/>
          </TabbedNavigation.Tab>
          <TabbedNavigation.Tab label="Hints">
            <HintsTab input={input} index={index}/>
          </TabbedNavigation.Tab>
          <ActivitySettings settings={[shuffleAnswerChoiceSetting(model, dispatch)]}/>
        </TabbedNavigation.Tabs>) : ('Select an input to edit it')}
    </>);
};
export class MultiInputAuthoring extends AuthoringElement {
    render(mountPoint, props) {
        ReactDOM.render(<Provider store={store}>
        <AuthoringElementProvider {...props}>
          <MultiInputComponent />
        </AuthoringElementProvider>
      </Provider>, mountPoint);
    }
}
// eslint-disable-next-line
const manifest = require('./manifest.json');
window.customElements.define(manifest.authoring.element, MultiInputAuthoring);
//# sourceMappingURL=MultiInputAuthoring.jsx.map