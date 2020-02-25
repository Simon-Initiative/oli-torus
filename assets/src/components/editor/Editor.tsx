import React, { useMemo, useCallback, KeyboardEvent } from 'react';
import { Slate, Editable, withReact } from 'slate-react';
import { createEditor, Node, NodeEntry, Editor as SlateEditor, Transforms } from 'slate';
import { withHistory } from 'slate-history';
import { create, Mark, ModelElement, schema, Paragraph } from 'data/content/model';
import { editorFor, markFor } from './editors';
import { ToolbarItem, gutterWidth } from './interfaces';
import { FixedToolbar, HoveringToolbar } from './Toolbars';
import { onKeyDown as listOnKeyDown } from './editors/Lists';
import { onKeyDown as quoteOnKeyDown } from './editors/Blockquote';
import guid from 'utils/guid';

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
    withReact(createEditor()))
    , []);

  // Override isVoid to incorporate our schema's opinion on which
  // elements are void
  editor.isVoid = (element) => {
    const result = (schema as any)[element.type].isVoid;
    return result;
  };

  editor.isInline = (element) => {
    const result = (schema as any)[element.type].isBlock;
    return !result;
  };

  const { normalizeNode } = editor;
  editor.normalizeNode = (entry: NodeEntry<Node>) => {

    // Ensure that we always have a paragraph as the last node in
    // the document, otherwise it can be impossible for a user
    // to position their cursor after the last node
    const [node] = entry;

    if (SlateEditor.isEditor(node)) {
      const last = node.children[node.children.length - 1];

      if (last.type !== 'p') {
        Transforms.insertNodes(editor, create<Paragraph>(
          { type: 'p', children: [{ text: '' }], id: guid() }),
          { mode: 'highest', at: SlateEditor.end(editor, []) });
      }
    }

    normalizeNode(entry);
  };

  const renderElement = useCallback((props) => {
    const model = props.element as ModelElement;
    return editorFor(model, props, editor);
  }, []);

  const onKeyDown = useCallback((e: KeyboardEvent) => {
    listOnKeyDown(editor, e);
    quoteOnKeyDown(editor, e);
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
