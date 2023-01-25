import { Model } from 'data/content/model/elements/factories';
import { Mark, Marks } from 'data/content/model/text';
import React, { FocusEventHandler, useCallback, useMemo } from 'react';
import { createEditor, Descendant, Editor as SlateEditor, Operation, Transforms } from 'slate';
import { withHistory } from 'slate-history';
import { Editable, RenderElementProps, RenderLeafProps, Slate, withReact } from 'slate-react';
import { classNames } from 'utils/classNames';
import { CommandContext, CommandDescription } from '../elements/commands/interfaces';
import { hotkeyHandler } from './handlers/hotkey';
import { onKeyDown as listOnKeyDown } from './handlers/lists';
import { onKeyDown as quoteOnKeyDown } from './handlers/quote';
import { onKeyDown as titleOnKeyDown } from './handlers/title';
import { onKeyDown as voidOnKeyDown } from './handlers/void';
import { editorFor, markFor } from './modelEditorDispatch';
import { installNormalizer, NormalizerContext } from './normalizers/normalizer';
import { withInlines } from './overrides/inlines';
import { withMarkdown } from './overrides/markdown';
import { withTables } from './overrides/tables';
import { withVoids } from './overrides/voids';
import { EditorToolbar } from 'components/editing/toolbar/editorToolbar/EditorToolbar';

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
  children?: React.ReactNode;
  onPaste?: React.ClipboardEventHandler<HTMLDivElement>;
  editorOverride?: SlateEditor;
  onFocus?: FocusEventHandler | undefined;
  onBlur?: FocusEventHandler | undefined;
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

export const Editor: React.FC<EditorProps> = React.memo((props: EditorProps) => {
  const editor = useMemo(() => {
    if (props.editorOverride) {
      return props.editorOverride;
    }
    const editor = withMarkdown(props.commandContext)(
      withReact(withHistory(withTables(withInlines(withVoids(createEditor()))))),
    );

    installNormalizer(editor, props.normalizerContext);
    return editor;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const renderElement = useCallback(
    (renderProps: RenderElementProps) =>
      editorFor(renderProps.element, renderProps, props.commandContext),
    [props.commandContext],
  );

  const onKeyDown = useCallback((e: React.KeyboardEvent) => {
    voidOnKeyDown(editor, e);
    listOnKeyDown(editor, e);
    quoteOnKeyDown(editor, e);
    titleOnKeyDown(editor, e);
    hotkeyHandler(editor, e.nativeEvent, props.commandContext);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

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
        value={props.value.length === 0 ? [Model.p()] : props.value}
        onChange={onChange}
      >
        {props.children}

        <EditorToolbar
          context={props.commandContext}
          insertOptions={props.toolbarInsertDescs}
          fixedToolbar={props.fixedToolbar}
        />

        <Editable
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
          onPaste={(e: React.ClipboardEvent<HTMLDivElement>) => {
            if (props.onPaste) return props.onPaste(e);

            const pastedText = e.clipboardData?.getData('text')?.trim();
            const youtubeRegex =
              /^(?:(?:https?:)?\/\/)?(?:(?:www|m)\.)?(?:(?:youtube\.com|youtu.be))(?:\/(?:[\w-]+\?v=|embed\/|v\/)?)([\w-]+)(?:\S+)?$/;
            const matches = pastedText.match(youtubeRegex);
            if (matches != null) {
              // matches[0] === the entire url
              // matches[1] === video id
              const [, videoId] = matches;
              e.preventDefault();
              Transforms.insertNodes(editor, [Model.youtube(videoId)]);
            }
          }}
        />
      </Slate>
    </React.Fragment>
  );
}, areEqual);
Editor.displayName = 'Editor';
