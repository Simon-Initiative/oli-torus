import React, { useState, useEffect, useRef } from 'react';
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


function positionPopup(el : HTMLElement, target : HTMLElement) {
  const menu = el;
  const rect = (target as any).getBoundingClientRect();

  (menu as any).style.position = 'absolute';
  (menu as any).style.top =
    ((rect as any).top + (window as any).pageYOffset) - 30 + 'px';

  const left = ((rect as any).left +
    window.pageXOffset -
    (menu as any).offsetWidth / 2 +
    (rect as any).width / 2) - 50;

  (menu as any).style.left = `${left}px`;
}

function hideToolbar(el: HTMLElement) {
  el.style.visibility = 'hidden';
}


const PopupTextEditor = (props: any) => {
  const ref = useRef()


  useEffect(() => {
    const el = ref.current as any;

    if (!el) {
      return;
    }
    console.log('popup')
    console.log(props.target.current);
    positionPopup(el, props.target.current);
  })

  const style = { marginTop: '5px' };


  const onTitleEdit = (e: any) => {
    const title = e.target.value;
    setIsEditing(false);
    onEdit(title);
  }

  const onCancel = () => setIsEditing(false);
  const onBeginEdit = () => setIsEditing(true);
  const onTextChange = (e: any) => {
    console.log("text change: " + e.target.value);
    setCurrent(e.target.value);
  }

  const onKeyUp = (e: any) => {
    if (e.keyCode === ESCAPE_KEYCODE) {
      onCancel();
    } else if (e.keyCode === ENTER_KEYCODE) {
      onTitleEdit(e);
    }
  };

  return ReactDOM.createPortal(
    <div ref={(ref as any)} style={{ position: 'relative' }}>
      <div style={{ display: 'inline' }}>
        <input type="text"
          onKeyUp={onKeyUp}
          onChange={onTextChange}
          value={current}
          style={style} />
        <button
          key="save"
          onClick={onTitleEdit}
          type="button"
          className="btn btn-sm">
          Done
        </button>
        <button
          key="cancel"
          onClick={props.onCancel}
          type="button"
          className="btn btn-sm">
          Cancel
        </button>
      </div>

    </div>, document.body
  )
}

export const AttributeEditor = (props: TextEditorProps) => {
  const ref = useRef();
  const [isEditing, setIsEditing] = useState(false);
  const { showAffordances, editMode } = props;
  const linkStyle: any = {
    display: 'inline-block',
    whiteSpace: 'normal',
    textAlign: 'left',
    color: 'black',
    fontWeight: 'normal',
  };

  return (
    <React.Fragment>
      <span ref={(ref as any)} style={linkStyle}>
        {props.model}
      </span>
      {showAffordances ? <button
        key="edit"
        onClick={() => setIsEditing(true)}
        type="button"
        disabled={!editMode || isEditing}
        className="btn btn-link btn-sm">
        Edit
      </button> : null}
      { isEditing ? <PopupTextEditor {...props} target={ref} showAffordances={true} editMode={true}/> : null}
    </React.Fragment>
  );
}



export const TextEditor = (props: TextEditorProps) => {

  const { model, showAffordances, onEdit, editMode } = props;
  const [ current, setCurrent ] = useState(model);
  const [ isEditing, setIsEditing ] = useState(false);

  console.log('isEditing ' + isEditing);

  const onTitleEdit = (e: any) => {
    const title = e.target.value;
    setIsEditing(false);
    onEdit(title);
  }

  const onCancel = () => setIsEditing(false);
  const onBeginEdit = () => setIsEditing(true);
  const onTextChange = (e: any) => {
    console.log("text change: " + e.target.value);
    setCurrent(e.target.value);
  }

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
      <div style={{ display: 'inline' }}>
        <input type="text"
          onKeyUp={onKeyUp}
          onChange={onTextChange}
          value={current}
          style={style} />
        <button
          key="save"
          onClick={onTitleEdit}
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
  }

  return isEditing ? editingUI() : readOnlyUI();

}
