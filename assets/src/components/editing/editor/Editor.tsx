import React, { FocusEventHandler, useCallback, useMemo } from 'react';
import { Descendant, Operation, Editor as SlateEditor, createEditor } from 'slate';
import { withHistory } from 'slate-history';
import { Editable, RenderElementProps, RenderLeafProps, Slate, withReact } from 'slate-react';
import { EditorToolbar } from 'components/editing/toolbar/editorToolbar/EditorToolbar';
import { Model } from 'data/content/model/elements/factories';
import { TextDirection } from 'data/content/model/elements/types';
import { Mark, Marks } from 'data/content/model/text';
import { classNames } from 'utils/classNames';
import { CommandContext, CommandDescription } from '../elements/commands/interfaces';
import { backspaceBlockKeyDown, deleteBlockKeyDown } from './handlers/deleteblock';
import { onKeyDown as linkOnKeyDown } from './handlers/deleteempty';
import { hotkeyHandler } from './handlers/hotkey';
import { onKeyDown as listOnKeyDown } from './handlers/lists';
import { onKeyDown as quoteOnKeyDown } from './handlers/quote';
import { onKeyDown as titleOnKeyDown } from './handlers/title';
import { onKeyDown as voidOnKeyDown } from './handlers/void';
import { editorFor, markFor } from './modelEditorDispatch';
import { NormalizerContext, installNormalizer } from './normalizers/normalizer';
import { withInlines } from './overrides/inlines';
import { withMarkdown } from './overrides/markdown';
import { withTables } from './overrides/tables';
import { withVoids } from './overrides/voids';
import { createOnPaste } from './paste/onPaste';

export type EditorProps = {
  // Callback when there has been any change to the editor
  onEdit: (value: Descendant[], editor: SlateEditor, operations: Operation[]) => void;
  // The content to display
  value: Descendant[];
  // The insertion toolbar configuration
  toolbarInsertDescs: CommandDescription[];
  // Whether or not editing is allowed
  editMode: boolean;
  fixedToolbar?: boolean;
  commandContext: CommandContext;
  normalizerContext?: NormalizerContext;
  className?: string;
  style?: React.CSSProperties;
  placeholder?: string;
  onPaste?: React.ClipboardEventHandler<HTMLDivElement>;
  children?: React.ReactNode;
  editorOverride?: SlateEditor;
  onFocus?: FocusEventHandler | undefined;
  onBlur?: FocusEventHandler | undefined;
  onSwitchToMarkdown?: () => void;
  textDirection?: TextDirection;
  onChangeTextDirection?: (textDirection: TextDirection) => void;
};

// Necessary to work around FireFox focus and selection issues with Slate
// https://github.com/ianstormtaylor/slate/issues/1984
function emptyOnFocus() {
  return;
}

function areEqual(prevProps: EditorProps, nextProps: EditorProps) {
  return (
    prevProps.editMode === nextProps.editMode &&
    prevProps.toolbarInsertDescs === nextProps.toolbarInsertDescs &&
    prevProps.value === nextProps.value &&
    prevProps.placeholder === nextProps.placeholder &&
    prevProps.children === nextProps.children
  );
}

const defaultValue = () => [Model.p()];
export const validateEditorContentValue = (value: any): Descendant[] => {
  if (!value) {
    return defaultValue();
  }
  if (!Array.isArray(value) && Array.isArray(value.model)) {
    // MER-2689 - Some content had an extra model property that was the array of elements.
    return value.model;
  }
  if (!Array.isArray(value) || value.length === 0) {
    return defaultValue();
  }
  return value;
};

export const Editor: React.FC<EditorProps> = React.memo((props: EditorProps) => {
  const editor = useMemo(() => {
    if (props.editorOverride) {
      return props.editorOverride;
    }

    const editor = withMarkdown(props.commandContext)(
      withReact(withHistory(withTables(withInlines(withVoids(createEditor()))))),
    );

    installNormalizer(editor, props.normalizerContext);

    // Force normalization on initial render, this will help a few use-cases:
    //   1. Our normalization code has changed since the last time this doc was opened
    //   2. The doc was created from another source (like the digest tool) and has never been opened.
    setTimeout(() => {
      SlateEditor.normalize(editor, { force: true });
    });

    return editor;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const onPaste = useMemo(() => {
    return props.onPaste || createOnPaste(editor);
  }, [editor, props.onPaste]);

  const renderElement = useCallback(
    (renderProps: RenderElementProps) =>
      editorFor(renderProps.element, renderProps, props.commandContext),
    [props.commandContext],
  );

  const onKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      voidOnKeyDown(editor, e);
      listOnKeyDown(editor, e);
      quoteOnKeyDown(editor, e);
      titleOnKeyDown(editor, e);
      hotkeyHandler(editor, e.nativeEvent, props.commandContext);
      backspaceBlockKeyDown(editor, e);
      deleteBlockKeyDown(editor, e);
      linkOnKeyDown(editor, e);
    },
    [editor, props.commandContext],
  );

  const renderLeaf = useCallback(({ attributes, children, leaf }: RenderLeafProps) => {
    const markup = Object.keys(leaf).reduce(
      (m, k) => (k in Marks ? markFor(k as Mark, m) : m),
      children,
    );
    return <span {...attributes}>{markup}</span>;
  }, []);

  const onChange = (value: Descendant[]) => {
    const { operations } = editor;

    // Determine if this onChange was due to an actual content change.
    // Otherwise, undo/redo will save pure selection changes.
    if (operations.filter(({ type }) => type !== 'set_selection').length) {
      props.onEdit(value, editor, operations);
    }
  };

  return (
    <React.Fragment>
      <Slate
        editor={editor}
        initialValue={validateEditorContentValue(props.value)}
        onChange={onChange}
      >
        {props.children}

        <EditorToolbar
          context={props.commandContext}
          insertOptions={props.toolbarInsertDescs}
          fixedToolbar={props.fixedToolbar}
          onSwitchToMarkdown={props.onSwitchToMarkdown}
          textDirection={props.textDirection}
          onChangeTextDirection={props.onChangeTextDirection}
        />

        <Editable
          dir={props.textDirection}
          style={props.style}
          className={classNames(
            'slate-editor',
            props.fixedToolbar && 'fixed-toolbar',
            props.className,
            !props.editMode && 'disabled',
          )}
          readOnly={!props.editMode}
          renderElement={renderElement}
          renderLeaf={renderLeaf}
          placeholder={props.placeholder ?? 'Type here or use + to begin...'}
          onKeyDown={onKeyDown}
          onFocus={props.onFocus || emptyOnFocus}
          onBlur={props.onBlur}
          onPaste={onPaste}
        />
      </Slate>
    </React.Fragment>
  );
}, areEqual);
Editor.displayName = 'Editor';
