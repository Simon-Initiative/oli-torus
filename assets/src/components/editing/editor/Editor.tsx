import { Mark, ModelElement } from 'data/content/model';
import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { createEditor, Editor as SlateEditor, Operation } from 'slate';
import { withHistory } from 'slate-history';
import {
  Editable,
  ReactEditor,
  RenderElementProps,
  RenderLeafProps,
  Slate,
  withReact,
} from 'slate-react';
import { CommandContext, ToolbarItem } from '../commands/interfaces';
import { formatMenuCommands } from '../toolbars/formatting/items';
import { FormattingToolbar } from '../toolbars/formatting/Toolbar';
import { shouldShowFormattingToolbar } from '../toolbars/formatting/utils';
import { HoveringToolbar } from '../toolbars/HoveringToolbar';
import { InsertionToolbar } from '../toolbars/insertion/Toolbar';
import { hotkeyHandler } from './handlers/hotkey';
import { onKeyDown as listOnKeyDown } from './handlers/lists';
import { onPaste } from './handlers/paste';
import { onKeyDown as quoteOnKeyDown } from './handlers/quote';
import { onKeyDown as titleOnKeyDown } from './handlers/title';
import { onKeyDown as voidOnKeyDown } from './handlers/void';
import { editorFor, markFor } from './modelEditorDispatch';
import { installNormalizer, NormalizerContext } from './normalizers/normalizer';
import { withInlines } from './overrides/inlines';
import { withMarkdown } from './overrides/markdown';
import { withTables } from './overrides/tables';
import { withVoids } from './overrides/voids';

export type EditorProps = {
  // Callback when there has been any change to the editor
  onEdit: (
    value: ModelElement[],
    editor: SlateEditor & ReactEditor,
    operations: Operation[],
  ) => void;
  // The content to display
  value: ModelElement[];
  // The insertion toolbar configuration
  toolbarItems: ToolbarItem[];
  // Whether or not editing is allowed
  editMode: boolean;
  commandContext: CommandContext;
  normalizerContext?: NormalizerContext;
  className?: string;
  style?: React.CSSProperties;
  placeholder?: string;
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
    prevProps.placeholder === nextProps.placeholder
  );
}

export const Editor: React.FC<EditorProps> = React.memo((props) => {
  const [isPerformingAsyncAction, setIsPerformingAsyncAction] = useState(false);

  const commandContext = props.commandContext;

  const editor: ReactEditor & SlateEditor = useMemo(
    () =>
      withMarkdown(commandContext)(
        withReact(withHistory(withTables(withInlines(withVoids(createEditor()))))),
      ),
    [],
  );
  const [installed, setInstalled] = useState(false);

  // Install the custom normalizer, only once
  useEffect(() => {
    if (!installed) {
      installNormalizer(editor, props.normalizerContext);
      setInstalled(true);
    }
  }, [installed]);

  const renderElement = useCallback(
    (props: RenderElementProps) => {
      const model = props.element as ModelElement;

      return editorFor(model, props, editor, commandContext);
    },
    [commandContext],
  );

  const onKeyDown = useCallback((e: React.KeyboardEvent) => {
    voidOnKeyDown(editor, e);
    listOnKeyDown(editor, e);
    quoteOnKeyDown(editor, e);
    titleOnKeyDown(editor, e);
    hotkeyHandler(editor, e.nativeEvent, commandContext);
  }, []);

  const renderLeaf = useCallback(({ attributes, children, leaf }: RenderLeafProps) => {
    const markup = Object.keys(leaf).reduce(
      (m, k) => (k !== 'text' ? markFor(k as Mark, m) : m),
      children,
    );
    return <span {...attributes}>{markup}</span>;
  }, []);

  const onChange = (value: ModelElement[]) => {
    const { operations } = editor;

    // Determine if this onChange was due to an actual content change.
    // Otherwise, undo/redo will save pure selection changes.
    if (operations.filter(({ type }) => type !== 'set_selection').length) {
      props.onEdit(value, editor, operations);
    }
  };

  const normalizedValue =
    props.value.length === 0 ? [{ type: 'p', children: [{ text: '' }] }] : props.value;

  return (
    <React.Fragment>
      <Slate
        editor={editor}
        value={normalizedValue}
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
        {props.children}
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
          style={props.style}
          className={'slate-editor overflow-auto' + (props.className ? ' ' + props.className : '')}
          readOnly={!props.editMode}
          renderElement={renderElement}
          renderLeaf={renderLeaf}
          placeholder={
            props.placeholder === undefined ? 'Enter some content here...' : props.placeholder
          }
          onKeyDown={onKeyDown}
        />
      </Slate>
    </React.Fragment>
  );
}, areEqual);
Editor.displayName = 'Editor';
