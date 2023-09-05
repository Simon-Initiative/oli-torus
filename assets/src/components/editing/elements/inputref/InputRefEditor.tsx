import React from 'react';
import { Transforms } from 'slate';
import { ReactEditor, useFocused, useSelected, useSlate } from 'slate-react';
import { friendlyType } from 'components/activities/vlab/utils';
import { initCommands } from 'components/editing/elements/inputref/actions';
import { EditorProps } from 'components/editing/elements/interfaces';
import { HoverContainer } from 'components/editing/toolbar/HoverContainer';
import { Toolbar } from 'components/editing/toolbar/Toolbar';
import { CommandButton } from 'components/editing/toolbar/buttons/CommandButton';
import * as ContentModel from 'data/content/model/elements/types';
import { classNames } from 'utils/classNames';

export interface InputRefEditorProps extends EditorProps<ContentModel.InputRef> {}
export const InputRefEditor = (props: InputRefEditorProps) => {
  const { inputRefContext } = props.commandContext;

  const focused = useFocused();
  const selected = useSelected();
  const editor = useSlate();

  const input = inputRefContext?.inputs.get(props.model.id);

  if (!inputRefContext || !input) {
    return (
      <span
        {...props.attributes}
        contentEditable={false}
        className="input-ref inline-block align-middle select-none rounded p-1 px-2 border border-red-500 bg-red-100 text-red-500 dark:text-red-600"
      >
        Missing Input Ref (delete){props.children}
      </span>
    );
  }

  const action = (e: React.MouseEvent | React.KeyboardEvent) => {
    e.preventDefault();
    inputRefContext?.setSelectedInputRef(props.model);
    Transforms.select(editor, ReactEditor.findPath(editor, props.model));
  };

  return (
    <span
      {...props.attributes}
      contentEditable={false}
      onKeyPress={(e: any) => {
        if (e.key === 'Enter') {
          action(e);
        }
      }}
    >
      <HoverContainer
        content={
          <Toolbar context={props.commandContext}>
            <Toolbar.Group>
              {initCommands(input, inputRefContext.setInputType, inputRefContext.isMultiInput).map(
                (desc, i) => (
                  <CommandButton description={desc} key={i} />
                ),
              )}
            </Toolbar.Group>
          </Toolbar>
        }
        isOpen={focused && selected}
      >
        <span
          onClick={(e) => action(e)}
          className={classNames(
            'input-ref inline-block align-middle select-none rounded p-1 px-2 whitespace-nowrap overflow-hidden border',
            inputRefContext.selectedInputRef?.id === props.model.id
              ? 'border-primary bg-blue-100 dark:bg-blue-700 text-primary dark:text-body-color-dark'
              : 'border-gray-400 dark:border-gray-600 text-gray-400 dark:text-gray-600',
            input.size && `input-size-${input.size}`,
          )}
        >
          {friendlyType(input.inputType)}
          {props.children}
        </span>
      </HoverContainer>
    </span>
  );
};
