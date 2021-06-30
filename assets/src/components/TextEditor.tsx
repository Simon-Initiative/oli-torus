import React, { useState, useEffect } from 'react';

export interface TextEditorProps {
  onEdit: (model: string) => void;
  model: string;
  showAffordances: boolean;
  editMode: boolean;
  size?: 'regular' | 'large';
  allowEmptyContents?: boolean;
}

export interface LabelledTextEditorProps extends TextEditorProps {
  label: string;
}

const ESCAPE_KEYCODE = 27;
const ENTER_KEYCODE = 13;

export const LabelledTextEditor = (props: LabelledTextEditorProps) => {
  return (
    <div>
      {props.label}: <TextEditor {...props} />
    </div>
  );
};

export const TextEditor = (props: TextEditorProps) => {
  const { model, showAffordances, onEdit, editMode } = props;
  const allowEmpty = props.allowEmptyContents === undefined ? true : props.allowEmptyContents;
  const [current, setCurrent] = useState(model);
  const [value, setValue] = useState(model);
  const [isEditing, setIsEditing] = useState(false);

  useEffect(() => {
    setCurrent(model);
  }, [model]);

  const isValid = (value: string) => value.trim() !== '';

  const onTitleEdit = (e: any) => {
    setIsEditing(false);
    if (isValid(value)) {
      setCurrent(value);
      onEdit(value);
    }
  };

  const onSave = (e: any) => {
    setIsEditing(false);
    if (isValid(value)) {
      setCurrent(value);
      onEdit(value);
    }
  };

  const onCancel = () => setIsEditing(false);

  const onBeginEdit = () => {
    setValue(current);
    setIsEditing(true);
  };

  const onTextChange = (e: any) => {
    setValue(e.target.value);
  };

  const onKeyUp = (e: any) => {
    if (e.keyCode === ESCAPE_KEYCODE) {
      onCancel();
    } else if (e.keyCode === ENTER_KEYCODE) {
      if (allowEmpty || isValid(value)) {
        onTitleEdit(e);
      }
    }
  };

  const editingUI = () => {
    const style = { marginTop: '5px', width: '90%', display: 'inline' };

    const validity = !allowEmpty && !isValid(value) ? 'is-invalid' : '';
    const size = props.size === 'large' ? 'form-control-lg' : '';
    const inputClass = `form-control ${validity} ${size} flex-fill`;

    return (
      <div data-slate-editor className="d-flex">
        <input
          type="text"
          className={inputClass}
          onKeyUp={onKeyUp}
          onChange={onTextChange}
          value={value}
          style={style}
        />
        <button
          key="save"
          onClick={onSave}
          type="button"
          disabled={!allowEmpty && !isValid(value)}
          className="btn btn-primary btn-sm my-2 ml-2"
        >
          Save
        </button>
        <button
          key="cancel"
          onClick={onCancel}
          type="button"
          className="btn btn-outline-secondary btn-sm my-2 ml-2"
        >
          Cancel
        </button>
      </div>
    );
  };

  const readOnlyUI = () => {
    const linkStyle: any = {
      display: 'inline-block',
      whiteSpace: 'normal',
      textAlign: 'left',
      fontWeight: 'normal',
      fontSize: props.size === 'large' ? '1.5rem' : '1rem',
    };

    return (
      <React.Fragment>
        <span style={linkStyle}>{current}</span>
        {showAffordances && (
          <button
            key="edit"
            onClick={onBeginEdit}
            type="button"
            disabled={!editMode}
            className="btn btn-link btn-sm"
          >
            Edit Title
          </button>
        )}
      </React.Fragment>
    );
  };

  return isEditing ? editingUI() : readOnlyUI();
};
