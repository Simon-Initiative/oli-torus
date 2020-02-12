import React, { useMemo, useRef, useEffect, useCallback } from 'react'
import * as ReactDOM from 'react-dom';

import { Slate, Editable, ReactEditor, withReact, useSlate } from 'slate-react'
import { Editor as SlateEditor, createEditor, Node } from 'slate'
import { withHistory } from 'slate-history'
import { Mark, ModelElement, schema } from './model';
import { editorFor, markFor, hoverMenuButtons } from './editors';
import { Range } from 'slate'
import { DOMElement } from 'slate-react/dist/utils/dom';

const withEmbeds = (editor: SlateEditor) => {
  const { isVoid } = editor;
  editor.isVoid = element => ((schema as any)[element.type].isVoid ? true : isVoid(element));
  return editor;
}

export type EditorProps = {
  onEdit: (value: any) => void;
  value: Node[];
}

export const Editor = (props: EditorProps) => {
  
  const editor = useMemo(() => withEmbeds(withHistory(withReact(createEditor()))), [])

  const renderElement = useCallback(props => {
    const model = props.element as ModelElement;
    return editorFor(model, props, editor);
  }, []);

  return (
    <Slate
      editor={editor as any}
      value={props.value}
      onChange={value => {
        props.onEdit(value);
      }}
    >
      <HoveringToolbar />
      <Editable
        renderElement={renderElement}
        renderLeaf={props => <Leaf {...props} />}
        placeholder="Enter some text..."
        onDOMBeforeInput={event => {
          switch ((event as any).inputType) {
            case 'formatBold':
              return editor.exec({ type: 'toggle_format', format: 'bold' })
            case 'formatItalic':
              return editor.exec({ type: 'toggle_format', format: 'italic' })
            case 'formatUnderline':
              return editor.exec({
                type: 'toggle_format',
                format: 'underlined',
              })
          }
        }}
      />
    </Slate>
  )
}

const isFormatActive = (editor: any, format: any) => {
  const [match] = SlateEditor.nodes(editor, {
    match: n => n[format] === true,
    mode: 'all',
  })
  return !!match
}


const Leaf = ({ attributes, children, leaf }: any) => {

  const markup =
    Object
      .keys(leaf)
      .reduce((m, k) => k !== 'text' ? markFor(k as Mark, m) : m, children);

  return <span {...attributes}>{markup}</span>
}



function positionAndShow(el : HTMLElement) {
  const menu = el;
  const native = window.getSelection() as any;
  const range = native.getRangeAt(0);
  const rect = (range as any).getBoundingClientRect();
  (menu as any).style.opacity = 1;
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
  el.style.opacity = '0';
}

function shouldHideToolbar(editor : ReactEditor) {
  const { selection } = editor;
  return  !selection ||
    !ReactEditor.isFocused(editor) ||
    Range.isCollapsed(selection) ||
    SlateEditor.string(editor, selection) === '';
}

const HoveringToolbar = () => {
  const ref = useRef()
  const editor = useSlate()

  useEffect(() => {
    const el = ref.current as any;

    if (!el) {
      return;
    }

    if (shouldHideToolbar(editor)) {
      hideToolbar(el);
    } else {
      positionAndShow(el);
    }
  })

  const style = {
    position: 'absolute',
    zIndex: 1,
    top: '0px',
    left: '0px',
    marginTop: '-6px',
    borderRadius: '4px',
    transition: 'opacity 0.75s',
  } as any;

  return ReactDOM.createPortal(
    <div ref={(ref as any)} style={{ opacity: 0, position: 'relative' }}>
      <div style={style} className="btn-group btn-group-sm" role="group" ref={(ref as any)}>
        {hoverMenuButtons.map(b => <FormatButton key={b.icon} icon={b.icon} command={b.command} />)}
      </div>
    </div>, document.body
  )
}

const FormatButton = ({ icon, command }: any) => {
  const editor = useSlate()
  return (
    <button
      className="btn btn-secondary"
      onMouseDown={event => {
        event.preventDefault()
        command(editor);
      }}
    >
      <i className={`${icon} icon`}></i>
    </button>
  )
}

