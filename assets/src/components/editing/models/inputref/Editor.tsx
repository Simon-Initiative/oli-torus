import { friendlyType } from 'components/activities/multi_input/utils';
import { initCommands } from 'components/editing/models/inputref/commands';
import { EditorProps } from 'components/editing/models/interfaces';
import { FormattingToolbar } from 'components/editing/toolbars/formatting/Toolbar';
import { HoveringToolbar } from 'components/editing/toolbars/HoveringToolbar';
import * as ContentModel from 'data/content/model/elements/types';
import { centeredAbove } from 'data/content/utils';
import React from 'react';
import { Transforms } from 'slate';
import { ReactEditor, useFocused, useSelected, useSlate } from 'slate-react';

export interface InputRefProps extends EditorProps<ContentModel.InputRef> {}
export const InputRefEditor = (props: InputRefProps) => {
  const { inputRefContext } = props.commandContext;

  const focused = useFocused();
  const selected = useSelected();
  const editor = useSlate();

  const input = inputRefContext?.inputs.get(props.model.id);

  const borderStyle =
    focused && selected
      ? { border: 'solid 3px lightblue', borderRadius: '0.25rem' }
      : { border: 'solid 3px transparent' };

  if (!inputRefContext || !input) {
    return (
      <span
        {...props.attributes}
        contentEditable={false}
        style={Object.assign(
          {
            border: '1px solid black',
            borderRadius: 3,
            padding: 4,
          },
          borderStyle,
        )}
      >
        Missing Input Ref (delete){props.children}
      </span>
    );
  }

  const commands = initCommands(input, inputRefContext.setInputType);

  const activeStyle =
    inputRefContext.selectedInputRef?.id === props.model.id
      ? { fontWeight: 'bold', backgroundColor: 'lightblue' }
      : {};

  const withToolbar = (target: React.ReactElement) => (
    <HoveringToolbar
      isOpen={() => focused && selected}
      showArrow
      target={target}
      contentLocation={centeredAbove}
    >
      <FormattingToolbar commandDescs={commands} commandContext={props.commandContext} />
    </HoveringToolbar>
  );

  const action = (e: React.MouseEvent | React.KeyboardEvent) => {
    e.preventDefault();
    inputRefContext?.setSelectedInputRef(props.model);
    Transforms.select(editor, ReactEditor.findPath(editor, props.model));
  };

  return (
    <span
      {...props.attributes}
      contentEditable={false}
      style={Object.assign(borderStyle, { display: 'inline-block' })}
      onKeyPress={(e) => {
        if (e.key === 'Enter') {
          action(e);
        }
      }}
    >
      {withToolbar(
        <span
          onClick={(e) => {
            action(e);
          }}
          style={Object.assign(activeStyle, {
            width: '160px',
            display: 'inline-block',
            userSelect: 'none',
          } as React.CSSProperties)}
          className="form-control"
        >
          {friendlyType(input.inputType)}
        </span>,
      )}
      {props.children}
    </span>
  );
};
