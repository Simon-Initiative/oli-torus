import React, { useState, useEffect } from 'react';
import ReactDOM from 'react-dom';

export interface TextEditorProps {
  onEdit: (model: string) => void;
  model: string;
  showAffordances: boolean;
  editMode: boolean;
}

export interface LabelledTextEditorProps extends TextEditorProps {
  label: string;
}

const ESCAPE_KEYCODE = 27;
const ENTER_KEYCODE = 13;

export const LabelledTextEditor = (props: LabelledTextEditorProps) => {
  return (
    <div>{props.label}: <TextEditor {...props}/></div>
  );
};

export const TextEditor = (props: TextEditorProps) => {

  const { model, showAffordances, onEdit, editMode } = props;
  const [current, setCurrent] = useState(model);
  const [isEditing, setIsEditing] = useState(false);

  useEffect(() => {
    setCurrent(model);
  }, [model]);

  const onTitleEdit = (e: any) => {
    setIsEditing(false);
    onEdit(current);
  };

  const onSave = (e: any) => {
    setIsEditing(false);
    onEdit(current);
  };

  const onCancel = () => setIsEditing(false);

  const onBeginEdit = () => {
    setIsEditing(true);
  };

  const onTextChange = (e: any) => {
    setCurrent(e.target.value);
  };

  const onKeyUp = (e: any) => {
    if (e.keyCode === ESCAPE_KEYCODE) {
      onCancel();
    } else if (e.keyCode === ENTER_KEYCODE) {
      onTitleEdit(e);
    }
  };

  const editingUI = () => {
    const style = { marginTop: '5px' };

    return (
      <div data-slate-editor style={{ display: 'inline' }}>
        <input type="text"
          onKeyUp={onKeyUp}
          onChange={onTextChange}
          value={current}
          style={style} />
        <button
          key="save"
          onClick={onSave}
          type="button"
          className="btn btn-sm">
          Done
        </button>
        <button
          key="cancel"
          onClick={onCancel}
          type="button"
          className="btn btn-sm">
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
      color: 'black',
      fontWeight: 'normal',
    };

    return (
      <React.Fragment>
        <span style={linkStyle}>
          {current}
        </span>
        {showAffordances ? <button
          key="edit"
          onClick={onBeginEdit}
          type="button"
          disabled={!editMode}
          className="btn btn-link btn-sm">
          Edit
        </button> : null}
      </React.Fragment>
    );
  };

  return isEditing ? editingUI() : readOnlyUI();

};
