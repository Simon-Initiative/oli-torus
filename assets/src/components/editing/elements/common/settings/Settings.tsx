import React, { useState, useRef } from 'react';
import { Popover } from 'react-tiny-popover';
import { ReactEditor, useSlate } from 'slate-react';
import { Transforms, Editor, Location } from 'slate';
import { cursorAtEndOfInput, cursorAtBeginningOfInput } from 'components/editing/utils';
import { ModelElement } from 'data/content/model/elements/types';
import { getEditMode } from 'components/editing/elements/utils';

// Reusable components for settings UIs

export const onEnterApply = (e: React.KeyboardEvent, onApply: () => void) => {
  if (e.key === 'Enter') {
    onApply();
  }
};

export const Action = ({ icon, onClick, tooltip, id }: any) => {
  return (
    <span
      id={id}
      data-toggle="tooltip"
      data-placement="top"
      title={tooltip}
      style={{ cursor: 'pointer ' }}
    >
      <i onClick={onClick} className={icon + ' mr-2'}></i>
    </span>
  );
};

export const ActionMaterial = ({ icon, onClick, tooltip, id }: any) => {
  return (
    <span
      id={id}
      data-toggle="tooltip"
      data-placement="top"
      title={tooltip}
      style={{ cursor: 'pointer ' }}
    >
      <i onClick={onClick} className="material-icons">
        {icon}
      </i>
    </span>
  );
};

interface SelectProps {
  value: string | undefined;
  onChange: (s: string) => void;
  options: string[];
  editor: Editor;
  style?: React.CSSProperties;
}

export const Select = (props: SelectProps) => {
  const { onChange, editor, style, options } = props;
  const [value, setValue] = useState(props.value);
  const ref = useRef();

  return (
    <select
      style={{ maxWidth: '120px', ...style }}
      ref={ref as any}
      className="form-control form-control-sm mb-2"
      value={value}
      onBlur={(_e) => ReactEditor.deselect(editor)}
      onChange={(e) => {
        setValue(e.target.value);
        onChange(e.target.value);
      }}
    >
      {options.map((o) => (
        <option key={o} value={o}>
          {o}
        </option>
      ))}
    </select>
  );
};

interface InputProps {
  value: string | undefined;
  onChange: (s: string) => void;
  placeholder: string;
  model: ModelElement;
}
export const Input = (props: InputProps) => {
  const { onChange, placeholder, model } = props;
  const editor = useSlate();
  const editMode = getEditMode(editor);
  const [value, setValue] = useState(props.value);
  const ref = useRef<HTMLInputElement | null>(null);

  return (
    <input
      style={{
        userSelect: editMode ? 'unset' : 'none',
      }}
      ref={ref}
      value={value || ''}
      placeholder={placeholder + ' (optional)'}
      onChange={(e) => {
        setValue(e.target.value);
        onChange(e.target.value);
      }}
      onBlur={(_e) => ReactEditor.deselect(editor)}
      onKeyDown={(e) => {
        const input = ref.current;
        if (!input) return;

        const changeSelection = (path: Location) => {
          ReactEditor.focus(editor);
          Transforms.select(editor, path);
        };
        const path = ReactEditor.findPath(editor, model);

        if (
          e.key === 'Enter' ||
          (e.key === 'ArrowDown' && cursorAtEndOfInput(input)) ||
          (e.key === 'ArrowRight' && cursorAtEndOfInput(input))
        ) {
          e.preventDefault();
          e.stopPropagation();
          const next = Editor.next(editor, { at: path });
          return next && changeSelection(next[1]);
        }
        if (
          (e.key === 'ArrowUp' && cursorAtBeginningOfInput(input)) ||
          (e.key === 'ArrowLeft' && cursorAtBeginningOfInput(input))
        ) {
          e.preventDefault();
          e.stopPropagation();
          return changeSelection(path);
        }
      }}
      className="settings-input"
    />
  );
};

export const ToolPopupButton = ({ setIsPopoverOpen, isPopoverOpen, contentFn, label }: any) => {
  return (
    <div style={{ float: 'right' }}>
      <Popover
        onClickOutside={() => {
          setIsPopoverOpen(false);
        }}
        isOpen={isPopoverOpen}
        padding={25}
        content={contentFn}
      >
        <button onClick={() => setIsPopoverOpen(true)} className="btn btn-light btn-sm mt-1">
          <i className="fas fa-cog mr-1"></i>
          {label ? `${label} Options` : 'Options'}
        </button>
      </Popover>
    </div>
  );
};
