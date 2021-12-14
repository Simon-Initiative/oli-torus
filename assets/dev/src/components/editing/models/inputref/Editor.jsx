import { friendlyType } from 'components/activities/multi_input/utils';
import { initCommands } from 'components/editing/models/inputref/commands';
import { FormattingToolbar } from 'components/editing/toolbars/formatting/Toolbar';
import { HoveringToolbar } from 'components/editing/toolbars/HoveringToolbar';
import { centeredAbove } from 'data/content/utils';
import React from 'react';
import { Transforms } from 'slate';
import { ReactEditor, useFocused, useSelected, useSlate } from 'slate-react';
export const InputRefEditor = (props) => {
    var _a;
    const { inputRefContext } = props.commandContext;
    const focused = useFocused();
    const selected = useSelected();
    const editor = useSlate();
    const input = inputRefContext === null || inputRefContext === void 0 ? void 0 : inputRefContext.inputs.get(props.model.id);
    const borderStyle = focused && selected
        ? { border: 'solid 3px lightblue', borderRadius: '0.25rem' }
        : { border: 'solid 3px transparent' };
    if (!inputRefContext || !input) {
        return (<span {...props.attributes} contentEditable={false} style={Object.assign({
                border: '1px solid black',
                borderRadius: 3,
                padding: 4,
            }, borderStyle)}>
        Missing Input Ref (delete){props.children}
      </span>);
    }
    const commands = initCommands(input, inputRefContext.setInputType);
    const activeStyle = ((_a = inputRefContext.selectedInputRef) === null || _a === void 0 ? void 0 : _a.id) === props.model.id
        ? { fontWeight: 'bold', backgroundColor: 'lightblue' }
        : {};
    const withToolbar = (target) => (<HoveringToolbar isOpen={() => focused && selected} showArrow target={target} contentLocation={centeredAbove}>
      <FormattingToolbar commandDescs={commands} commandContext={props.commandContext}/>
    </HoveringToolbar>);
    const action = (e) => {
        e.preventDefault();
        inputRefContext === null || inputRefContext === void 0 ? void 0 : inputRefContext.setSelectedInputRef(props.model);
        Transforms.select(editor, ReactEditor.findPath(editor, props.model));
    };
    return (<span {...props.attributes} contentEditable={false} style={Object.assign(borderStyle, { display: 'inline-block' })} onKeyPress={(e) => {
            if (e.key === 'Enter') {
                action(e);
            }
        }}>
      {withToolbar(<span onClick={(e) => {
                action(e);
            }} style={Object.assign(activeStyle, {
                width: '160px',
                display: 'inline-block',
                userSelect: 'none',
            })} className="form-control">
          {friendlyType(input.inputType)}
        </span>)}
      {props.children}
    </span>);
};
//# sourceMappingURL=Editor.jsx.map