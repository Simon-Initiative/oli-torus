import { friendlyType } from 'components/activities/multi_input/utils';
import { EditorProps } from 'components/editing/elements/interfaces';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import * as ContentModel from 'data/content/model/elements/types';
import React from 'react';
import { Transforms } from 'slate';
import { ReactEditor, useFocused, useSelected, useSlate } from 'slate-react';
import { initCommands } from 'components/editing/elements/inputref/inputrefActions';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';

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

  const activeStyle =
    inputRefContext.selectedInputRef?.id === props.model.id
      ? { fontWeight: 'bold', backgroundColor: 'lightblue' }
      : {};

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
      <HoverContainer
        content={
          <Toolbar context={props.commandContext}>
            <Toolbar.Group>
              {initCommands(input, inputRefContext.setInputType).map((desc, i) => (
                <CommandButton description={desc} key={i} />
              ))}
            </Toolbar.Group>
          </Toolbar>
        }
        isOpen={focused && selected}
      >
        <span
          onClick={(e) => action(e)}
          style={Object.assign(activeStyle, {
            width: '160px',
            display: 'inline-block',
            userSelect: 'none',
          } as React.CSSProperties)}
          className="form-control"
        >
          {friendlyType(input.inputType)}
          {props.children}
        </span>
      </HoverContainer>
    </span>
  );
};
