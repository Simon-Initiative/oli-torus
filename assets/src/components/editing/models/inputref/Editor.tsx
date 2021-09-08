import React from 'react';
import * as ContentModel from 'data/content/model';
import { EditorProps } from 'components/editing/models/interfaces';
import { DropdownInput } from 'components/activities/multi_input/sections/delivery/DropdownInput';
import { ReactEditor, useEditor, useFocused, useSelected } from 'slate-react';
import { Transforms } from 'slate';

// eslint-disable-next-line
export interface InputRefProps extends EditorProps<ContentModel.InputRef> {}

export const InputRefEditor = (props: InputRefProps) => {
  const { attributes, children, model } = props;

  const editor = useEditor();
  const focused = useFocused();
  const selected = useSelected();

  const borderStyle =
    focused && selected
      ? { border: 'solid 3px lightblue', borderRadius: '0.25rem' }
      : { border: 'solid 3px transparent' };

  const shared = {
    disabled: true,
    onClick: () => Transforms.select(editor, ReactEditor.findPath(editor, model)),
    onChange: () => undefined,
  };

  const element = {
    dropdown: <DropdownInput {...shared} options={[{ value: '1', content: '1' }]} />,
    text: (
      <input
        {...shared}
        style={{ width: '160px', display: 'inline-block' }}
        className="form-control"
      />
    ),
    numeric: (
      <input
        {...shared}
        style={{ width: '160px', display: 'inline-block' }}
        className="form-control"
      />
    ),
  }[props.model.inputType];

  return (
    <span
      {...attributes}
      contentEditable={false}
      style={Object.assign(borderStyle, { display: 'inline-block' })}
    >
      {element}
      {children}
    </span>
  );
};
