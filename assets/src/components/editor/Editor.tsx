import React, { useMemo, useCallback, KeyboardEvent } from 'react';
import { Slate, Editable, withReact } from 'slate-react';
import { createEditor, Node, Point, Range, Transforms, Editor as SlateEditor } from 'slate';
import { withHistory } from 'slate-history';
import { Mark, ModelElement, schema } from 'data/content/model';
import { editorFor, markFor } from './editors';
import { ToolbarItem, gutterWidth } from './interfaces';
import { FixedToolbar, HoveringToolbar } from './Toolbars';
import { withLists, onKeyDown as listOnKeyDown } from './editors/Lists';

export type EditorProps = {
  // Callback when there has been any change to the editor (including selection state)
  onEdit: (value: any) => void;

  // The content to display
  value: Node[];

  // The fixed toolbar configuration
  toolbarItems: ToolbarItem[];
};

export const Editor = (props: EditorProps) => {

  const editor = useMemo(() => withHistory(
    withLists(
      withReact(createEditor())))
    , []);

  // Override isVoid to incorporate our schema's opinion on which
  // elements are void
  editor.isVoid = (element) => {
    const result = (schema as any)[element.type].isVoid;
    return result;
  };

  const renderElement = useCallback((props) => {
    const model = props.element as ModelElement;
    return editorFor(model, props, editor);
  }, []);

  const onKeyDown = useCallback((e: KeyboardEvent) => {
    listOnKeyDown(editor, e);
  }, []);

  const renderLeaf = useCallback(({ attributes, children, leaf }: any) => {
    const markup =
      Object
        .keys(leaf)
        .reduce((m, k) => k !== 'text' ? markFor(k as Mark, m) : m, children);
    return <span {...attributes}>{markup}</span>;
  }, []);


  const border = {
    border: 'solid lightgray 1px',
    padding: '4px',
    paddingRight: gutterWidth + 'px',
  };

  return (
    <div style={border}>

      <Slate
        editor={editor as any}
        value={props.value}
        onChange={value => props.onEdit(value)}
      >
        <FixedToolbar toolbarItems={props.toolbarItems} />

        <HoveringToolbar />

        <Editable
          renderElement={renderElement}
          renderLeaf={renderLeaf}
          placeholder="Enter some text..."
          onKeyDown={onKeyDown}
        />
      </Slate>
    </div>
  );
};
