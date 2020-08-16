import React, { useMemo, useCallback, useEffect, useState } from 'react';
import { Slate, Editable, withReact, ReactEditor } from 'slate-react';
import { createEditor, Node, Point, Range, Editor as SlateEditor, Transforms, Path } from 'slate';
import isHotkey from 'is-hotkey';
import {
  create, Mark, ModelElement, schema, Paragraph,
  SchemaConfig, Selection,
} from 'data/content/model';
import { editorFor, markFor } from './editors';
import { ToolbarItem, CommandContext } from './commands/interfaces';
import { onKeyDown as listOnKeyDown } from './editors/Lists';
import { commandDesc as linkCmd } from 'components/editor/commands/buttons/Link';
import { getNearestBlock } from './utils';
import { toggleMark } from './commands/commands';
import { installNormalizer } from './normalizer';
import guid from 'utils/guid';
import { ToolbarPosition, FixedToolbar } from './toolbars/Fixed';
import { HoveringToolbar } from './toolbars/Hovering';

export type EditorProps = {
  // Callback when there has been any change to the editor (including selection state)
  onEdit: (value: ModelElement[], selection: Selection) => void;

  // The content to display
  value: ModelElement[];

  // The current selection
  selection: Selection;

  // The fixed toolbar configuration
  toolbarItems: ToolbarItem[];

  // Whether or not editing is allowed
  editMode: boolean;

  commandContext: CommandContext;

  toolbarPosition?: ToolbarPosition;
};

// Pressing the Enter key on any void block should insert an empty
// paragraph after that node
const voidOnKeyDown = (editor: ReactEditor, e: React.KeyboardEvent) => {

  if (e.key === 'Enter') {
    if (editor.selection && Range.isCollapsed(editor.selection)) {

      getNearestBlock(editor).lift((node: Node) => {

        const nodeType = node.type as string;
        const schemaItem : SchemaConfig = (schema as any)[nodeType];

        if (schemaItem.isVoid) {
          const path = ReactEditor.findPath(editor, node);
          Transforms.insertNodes(editor, create<Paragraph>(
            { type: 'p', children: [{ text: '' }], id: guid() }),
            { at: Path.next(path) });

          Transforms.select(editor, Path.next(path));
        }
      });

    }
  }
};


// Handles exiting a header item via Enter key, setting the next block back to normal (p)
function handleFormattingTermination(editor: SlateEditor, e: React.KeyboardEvent) {
  if (e.key === 'Enter' && editor.selection && Range.isCollapsed(editor.selection)) {

    const [match] = SlateEditor.nodes(editor, {
      match: n => n.type === 'h1' || n.type === 'h2'
      || n.type === 'h3' || n.type === 'h4'
      || n.type === 'h5' || n.type === 'h6',
    });

    if (match) {
      const [, path] = match;

      const end = SlateEditor.end(editor, path);

      // If the cursor is at the end of the block
      if (Point.equals(editor.selection.focus, end)) {

        const p = create<Paragraph>(
          { type: 'p', children: [{ text: '' }], id: guid() });

        // Insert it ahead of the next node
        const nextMatch = SlateEditor.next(editor, { at: path });
        if (nextMatch) {
          const [, nextPath] = nextMatch;
          Transforms.insertNodes(editor, p, { at: nextPath });

          const newNext = SlateEditor.next(editor, { at: path });
          if (newNext) {
            const [, newPath] = newNext;
            Transforms.select(editor, newPath);
          }


        // But if there is no next node, insert it at end
        } else {
          Transforms.insertNodes(editor, p, { mode: 'highest', at: SlateEditor.end(editor, []) });

          const newNext = SlateEditor.next(editor, { at: path });
          if (newNext) {
            const [, newPath] = newNext;
            Transforms.select(editor, newPath);
          }
        }

        e.preventDefault();
      }
    }
  }
}


function areEqual(prevProps: EditorProps, nextProps: EditorProps) {
  return prevProps.editMode === nextProps.editMode
    && prevProps.toolbarItems === nextProps.toolbarItems
    && prevProps.value === nextProps.value;
}


export const Editor = React.memo((props: EditorProps) => {

  const commandContext = props.commandContext;

  const editor = useMemo(() => withReact(createEditor()), []);
  const [installed, setInstalled] = useState(false);

  // Install the custom normalizer, only once
  useEffect(() => {
    if (!installed) {
      installNormalizer(editor);
      setInstalled(true);
    }
  }, [installed]);

  // Override isVoid to incorporate our schema's opinion on which
  // elements are void
  editor.isVoid = (element) => {
    try {
      const result = (schema as any)[element.type as string].isVoid;
      return result;
    } catch (e) {
      return false;
    }

  };

  editor.isInline = (element) => {
    try {
      const result = (schema as any)[element.type as string].isBlock;
      return !result;
    } catch (e) {
      return false;
    }
  };

  if (props.selection !== undefined) {
    editor.selection = props.selection;
  }

  const renderElement = useCallback((props) => {
    const model = props.element as ModelElement;

    return editorFor(model, props, editor, commandContext);
  }, []);

  // register hotkeys
  const isBoldHotkey = isHotkey('mod+b');
  const isItalicHotkey = isHotkey('mod+i');
  const isCodeHotkey = isHotkey('mod+;');
  const isLinkHotkey = isHotkey('mod+l');

  const hotkeyHandler = (editor: ReactEditor, e: KeyboardEvent) => {
    if (isBoldHotkey(e)) {
      toggleMark(editor, 'strong');
    } else if (isItalicHotkey(e)) {
      toggleMark(editor, 'em');
    } else if (isCodeHotkey(e)) {
      toggleMark(editor, 'code');
    } else if (isLinkHotkey(e)) {
      linkCmd.command.execute(props.commandContext, editor);
    }
  };

  const onKeyDown = useCallback((e: React.KeyboardEvent) => {
    voidOnKeyDown(editor, e);
    listOnKeyDown(editor, e);
    handleFormattingTermination(editor, e);
    hotkeyHandler(editor, e.nativeEvent);
  }, []);

  const renderLeaf = useCallback(({ attributes, children, leaf }: any) => {
    const markup =
      Object
        .keys(leaf)
        .reduce((m, k) => k !== 'text' ? markFor(k as Mark, m) : m, children);
    return <span {...attributes}>{markup}</span>;
  }, []);

  const onChange = (value: ModelElement[]) => {
    const { operations, selection } = editor;

    // Determine if this onChange was due to an actual content change
    if (operations.filter(({ type }) => type !== 'set_selection').length) {
      props.onEdit(value, selection);
    }
  };

  return (
    <div>

      <Slate
        editor={editor as any}
        value={props.value}
        onChange={onChange}
        >
        <FixedToolbar position={props.toolbarPosition} toolbarItems={props.toolbarItems}
          commandContext={props.commandContext} />

        <HoveringToolbar commandContext={props.commandContext}/>

        <Editable
          className="slate-editor"
          readOnly={!props.editMode}
          renderElement={renderElement}
          renderLeaf={renderLeaf}
          placeholder="Enter some content here..."
          onKeyDown={onKeyDown}
        />
      </Slate>
    </div>
  );
}, areEqual);
