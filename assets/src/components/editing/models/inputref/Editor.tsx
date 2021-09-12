import React from 'react';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editing/models/interfaces';
import { DropdownInput } from 'components/activities/multi_input/sections/delivery/DropdownInput';
import { ReactEditor, useEditor, useFocused, useSelected } from 'slate-react';
import { Transforms } from 'slate';
import { initCommands } from 'components/editing/models/inputref/commands';
import { HoveringToolbar } from 'components/editing/toolbars/HoveringToolbar';
import { FormattingToolbar } from 'components/editing/toolbars/formatting/Toolbar';
import { centeredAbove } from 'data/content/utils';
import { friendlyType } from 'components/activities/multi_input/utils';

export interface InputRefProps extends EditorProps<ContentModel.InputRef> {}

export const InputRefEditor = (props: InputRefProps) => {
  const { inputRefContext } = props.commandContext;

  const editor = useEditor();
  const focused = useFocused();
  const selected = useSelected();

  const input = inputRefContext?.inputs.get(props.model.id);
  if (!inputRefContext || !input) {
    return null;
  }

  console.log('input ref context', inputRefContext, props.model.id);

  const commands = initCommands(input, inputRefContext.onEditInput);

  const borderStyle =
    focused && selected
      ? { border: 'solid 3px lightblue', borderRadius: '0.25rem' }
      : { border: 'solid 3px transparent' };

  const shared = {
    disabled: true,
    onClick: () => Transforms.select(editor, ReactEditor.findPath(editor, props.model)),
  };

  console.log('re-rendering');

  const withToolbar = (target: React.ReactElement) => (
    <HoveringToolbar
      isOpen={() => focused && selected}
      showArrow
      target={target}
      contentLocation={(state) => {
        console.log('state', state);
        return centeredAbove(state);
      }}
    >
      <FormattingToolbar commandDescs={commands} commandContext={props.commandContext} />
    </HoveringToolbar>
  );

  return (
    <span
      {...props.attributes}
      contentEditable={false}
      style={Object.assign(borderStyle, { display: 'inline-block' })}
    >
      {withToolbar(
        <input
          {...shared}
          style={{ width: '160px', display: 'inline-block' }}
          className="form-control"
          value={friendlyType(input.inputType)}
        />,
      )}
      {props.children}
    </span>
  );
};
