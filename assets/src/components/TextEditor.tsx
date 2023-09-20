import React, { useEffect, useState } from 'react';
import { Button } from 'components/common/Buttons';
import { TextInput } from 'components/common/inputs';
import { classNames } from 'utils/classNames';
import { valueOr } from 'utils/common';

export interface TextEditorProps {
  editMode: boolean;
  model: string;
  label?: string;
  showAffordances: boolean;
  size?: 'regular' | 'large';
  allowEmptyContents?: boolean;
  onEdit: (model: string) => void;
}

const ESCAPE_KEYCODE = 27;
const ENTER_KEYCODE = 13;

export const TextEditor = (props: TextEditorProps) => {
  const { editMode, model, label, showAffordances, onEdit } = props;
  const allowEmpty = props.allowEmptyContents === undefined ? true : props.allowEmptyContents;
  const [current, setCurrent] = useState(model);
  const [value, setValue] = useState(model);
  const [isEditing, setIsEditing] = useState(false);

  useEffect(() => {
    setCurrent(model);
  }, [model]);

  const isValid = (value: string) => value.trim() !== '';

  const onTitleEdit = () => {
    setIsEditing(false);
    if (isValid(value)) {
      setCurrent(value);
      onEdit(value);
    }
  };

  const onSave = () => {
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
        onTitleEdit();
      }
    }
  };

  const editingUI = () => {
    return (
      <div data-slate-editor className="d-flex inline-flex flex-grow-1">
        <TextInput
          className={classNames('flex-1', !allowEmpty && isValid(value) ? 'is-invalid' : '')}
          size="sm"
          onKeyUp={onKeyUp}
          onChange={onTextChange}
          value={value}
          autoSelect={true}
        />
        <div className="whitespace-nowrap">
          <Button
            className="ml-2"
            variant="primary"
            size="sm"
            onClick={onSave}
            disabled={!allowEmpty && !isValid(value)}
          >
            Save
          </Button>
          <Button className="ml-1" variant="secondary" size="sm" onClick={onCancel}>
            Cancel
          </Button>
        </div>
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
            {valueOr(label, 'Edit Title')}
          </button>
        )}
      </React.Fragment>
    );
  };

  return isEditing ? editingUI() : readOnlyUI();
};
