import React, { useMemo, useCallback, useEffect, useState } from 'react';
import { Slate, Editable, withReact, ReactEditor } from 'slate-react';
import { createEditor, Editor as SlateEditor, Range } from 'slate';
import { Mark, ModelElement, Selection } from 'data/content/model';
import { editorFor, markFor } from './modelEditorDispatch';
import { ToolbarItem, CommandContext } from '../commands/interfaces';
import { installNormalizer } from './normalizers/normalizer';
import { InsertionToolbar } from '../toolbars/insertion/Toolbar';
import { formatMenuCommands } from '../toolbars/formatting/items';
import { shouldShowFormattingToolbar } from '../toolbars/formatting/utils';
import { onKeyDown as quoteOnKeyDown } from './handlers/quote';
import { onKeyDown as listOnKeyDown } from './handlers/lists';
import { onKeyDown as voidOnKeyDown } from './handlers/void';
import { onKeyDown as titleOnKeyDown } from './handlers/title';
import { hotkeyHandler } from './handlers/hotkey';
import { HoveringToolbar } from '../toolbars/HoveringToolbar';
import { FormattingToolbar } from '../toolbars/formatting/Toolbar';
import { withVoids } from './overrides/voids';
import { withInlines } from './overrides/inlines';
import { withTables } from './overrides/tables';
import { withMarkdown } from './overrides/markdown';
import { onPaste } from './handlers/paste';

export type EditorProps = {
  // Callback when there has been any change to the editor (including selection state)
  onEdit: (value: ModelElement[], selection: Selection) => void;
  // The content to display
  value: ModelElement[];
  // The current selection
  selection: Selection;
  // The insertion toolbar configuration
  toolbarItems: ToolbarItem[];
  // Whether or not editing is allowed
  editMode: boolean;
  commandContext: CommandContext;
  className?: string;
};

// Necessary to work around FireFox focus and selection issues with Slate
// https://github.com/ianstormtaylor/slate/issues/1984
function emptyOnFocus() {
  return;
}

function areEqual(prevProps: EditorProps, nextProps: EditorProps) {
  return (
    prevProps.editMode === nextProps.editMode &&
    prevProps.toolbarItems === nextProps.toolbarItems &&
    prevProps.value === nextProps.value &&
    !!prevProps.selection &&
    !!nextProps.selection &&
    Range.equals(prevProps.selection, nextProps.selection)
  );
}
// eslint-disable-next-line
export const Editor = React.memo((props: EditorProps) => {
  const [isPerformingAsyncAction, setIsPerformingAsyncAction] = useState(false);

  const commandContext = props.commandContext;

  const editor: ReactEditor & SlateEditor = useMemo(
    () =>
      withMarkdown(commandContext)(withReact(withTables(withInlines(withVoids(createEditor()))))),
    [],
  );
  const [installed, setInstalled] = useState(false);

  // Install the custom normalizer, only once
  useEffect(() => {
    if (!installed) {
      installNormalizer(editor);
      setInstalled(true);
    }
  }, [installed]);

  // Pure selection changes are uncontrolled and maintained in the Slate Editable state.
  // Content changes propagate through onEdit along with the selection to allow undo/redo
  // to override the selection when undo/redo is triggered.
  if (props.selection) {
    editor.selection = props.selection;
  }

  const renderElement = useCallback((props) => {
    const model = props.element as ModelElement;

    return editorFor(model, props, editor, commandContext);
  }, []);

  const onKeyDown = useCallback((e: React.KeyboardEvent) => {
    voidOnKeyDown(editor, e);
    listOnKeyDown(editor, e);
    quoteOnKeyDown(editor, e);
    titleOnKeyDown(editor, e);
    hotkeyHandler(editor, e.nativeEvent, commandContext);
  }, []);

  const renderLeaf = useCallback(({ attributes, children, leaf }: any) => {
    const markup = Object.keys(leaf).reduce(
      (m, k) => (k !== 'text' ? markFor(k as Mark, m) : m),
      children,
    );
    return <span {...attributes}>{markup}</span>;
  }, []);

  const onChange = (value: ModelElement[]) => {
    const { operations, selection } = editor;

    // Determine if this onChange was due to an actual content change.
    // Otherwise, undo/redo will save pure selection changes.
    if (operations.filter(({ type }) => type !== 'set_selection').length) {
      props.onEdit(value, selection);
    }
  };

  return (
    <React.Fragment>
      <Slate
        editor={editor}
        value={props.value}
        onChange={onChange}
        onFocus={emptyOnFocus}
        onPaste={async (
          e: React.ClipboardEvent<HTMLDivElement>,
          editor: SlateEditor,
          // eslint-disable-next-line
          next: Function,
        ) => {
          setIsPerformingAsyncAction(true);
          await onPaste(editor, e, props.commandContext.projectSlug);
          setIsPerformingAsyncAction(false);
          next();
        }}
      >
        <InsertionToolbar
          isPerformingAsyncAction={isPerformingAsyncAction}
          toolbarItems={props.toolbarItems}
          commandContext={props.commandContext}
        />

        <HoveringToolbar isOpen={shouldShowFormattingToolbar}>
          <FormattingToolbar
            commandDescs={formatMenuCommands}
            commandContext={props.commandContext}
          />
        </HoveringToolbar>

        <Editable
          className={'slate-editor' + (props.className ? ' ' + props.className : '')}
          readOnly={!props.editMode}
          renderElement={renderElement}
          renderLeaf={renderLeaf}
          placeholder="Enter some content here..."
          onKeyDown={onKeyDown}
        />
      </Slate>
    </React.Fragment>
  );
}, areEqual);
