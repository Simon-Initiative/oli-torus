import React, { useState, useMemo, useRef, useEffect, useCallback } from 'react'
import * as ReactDOM from 'react-dom';

import { Slate, Editable, ReactEditor, withReact, useSlate } from 'slate-react'
import { Editor, createEditor, Node } from 'slate'
import { withHistory } from 'slate-history'
import { Mark, ModelElement, schema } from './model';
import { editorFor, markFor, hoverMenuButtons } from './editors';
import { Range } from 'slate'

const withEmbeds = (editor: Editor) => {
  const { isVoid } = editor;
  editor.isVoid = element => ((schema as any)[element.type].isVoid ? true : isVoid(element));
  return editor;
}

export type EditorProps = {
  onEdit: (value: any) => void;
  value: Node[];
}

export const EditorComponent = (props: EditorProps) => {
  const [value, setValue] = useState(props.value)
  const editor = useMemo(() => withEmbeds(withHistory(withReact(createEditor()))), [])

  const renderElement = useCallback(props => {
    const model = props.element as ModelElement;
    return editorFor(model, props, editor);
  }, []);

  return (
    <Slate
      editor={editor as any}
      value={value}
      onChange={value => {
        setValue(value as any)
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
  const [match] = Editor.nodes(editor, {
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

const HoveringToolbar = () => {
  const ref = useRef()
  const editor = useSlate()

  useEffect(() => {
    const el = ref.current as any;
    const { selection } = editor

    if (!el) {
      return
    }

    if (
      !selection ||
      !ReactEditor.isFocused(editor) ||
      Range.isCollapsed(selection) ||
      Editor.string(editor, selection) === ''
    ) {
      el.removeAttribute('style')
      return
    }

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

    (menu as any).style.left = `${left}px`

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
      <div
        style={style}
        className="ui small icon buttons"
        ref={(ref as any)}>

        {hoverMenuButtons.map(b => <FormatButton icon={b.icon} command={b.command} />)}

      </div>
    </div>, document.body
  )
}

const FormatButton = ({ icon, command }: any) => {
  const editor = useSlate()
  return (
    <button
      className="ui button secondary"
      onMouseDown={event => {
        event.preventDefault()
        command(editor);
      }}
    >
      <i className={`${icon} icon`}></i>
    </button>
  )
}

