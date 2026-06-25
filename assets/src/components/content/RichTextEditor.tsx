import React from 'react';
import debounce from 'lodash/debounce';
import { Descendant, Operation, Editor as SlateEditor } from 'slate';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { MediaItemRequest } from 'components/activities/types';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { Editor } from 'components/editing/editor/Editor';
import { NormalizerContext } from 'components/editing/editor/normalizers/normalizer';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { blockInsertOptions } from 'components/editing/toolbar/editorToolbar/blocks/blockInsertOptions';
import { ProjectSlug } from 'data/types';
import { classNames } from 'utils/classNames';

type Props = {
  projectSlug: ProjectSlug;
  editMode: boolean;
  value: Descendant[];
  className?: string;
  placeholder?: string;
  style?: React.CSSProperties;
  commandContext?: CommandContext;
  // Email-mode link picker source (see CommandContext.linkContext). When provided, merged
  // into the editor's commandContext so the link command/modal use internal course pages.
  linkContext?: CommandContext['linkContext'];
  normalizerContext?: NormalizerContext;
  fixedToolbar?: boolean;
  allowBlockElements?: boolean;
  textDirection?: 'ltr' | 'rtl';
  onChangeTextDirection?: (textDirection: 'ltr' | 'rtl') => void;
  onEdit: (value: Descendant[], editor: SlateEditor, operations: Operation[]) => void;
  onRequestMedia?: (request: MediaItemRequest) => Promise<string | boolean>;
  // the name of the event to be pushed back to the liveview (or live_component) when rendered with React.component
  onEditEvent?: string;
  // the name of the event target element (if the target is a live_component, ex: "#my-live-component-id")
  onEditTarget?: string;
  pushEvent?: (event: string, payload: any) => void;
  pushEventTo?: (selectorOrTarget: string, event: string, payload: any) => void;
  // When set (and rendered within LiveView via onEditEvent), debounce edit pushes
  // by this many ms instead of pushing the full body on every keystroke. Pending
  // edits are flushed on blur/unmount so a Send (which blurs first) sees the latest.
  onEditDebounceMs?: number;
};
export const RichTextEditor: React.FC<Props> = ({
  projectSlug,
  editMode,
  value,
  className,
  placeholder,
  style,
  commandContext,
  linkContext,
  normalizerContext,
  fixedToolbar = false,
  allowBlockElements = true,
  onEdit,
  onRequestMedia,
  children,
  textDirection,
  onChangeTextDirection,
  onEditEvent,
  onEditTarget,
  pushEvent,
  pushEventTo,
  onEditDebounceMs,
}) => {
  // Support content persisted when RichText had a `model` property.
  value = (value as any).model ? (value as any).model : value;

  // Support for rendering the component within a LiveView or a LiveComponent:
  // if onEditEvent is not null it means this react component is rendered within a LiveView or a live_component
  // using the React.component wrapper
  // If so, events need to be pushed back to the LiveView or the live_component (the optional onEditTarget is used to target the event to a live_component)

  // Push the edit back to the LiveView. Hooks run unconditionally (Rules of Hooks);
  // they are only wired in below when this is rendered in LiveView bridge mode.
  const pushEdit = React.useCallback(
    (values: Descendant[]) => {
      if (!onEditEvent) return;

      if (onEditTarget && pushEventTo) {
        pushEventTo(onEditTarget, onEditEvent, { values });
      } else if (pushEvent) {
        pushEvent(onEditEvent, { values });
      }
    },
    [onEditEvent, onEditTarget, pushEvent, pushEventTo],
  );

  const debouncedPush = React.useMemo(
    () =>
      onEditDebounceMs && onEditDebounceMs > 0
        ? debounce(pushEdit, onEditDebounceMs, { maxWait: onEditDebounceMs * 5 })
        : null,
    [pushEdit, onEditDebounceMs],
  );

  // Flush pending debounced edits on unmount so the last keystrokes are not lost.
  React.useEffect(() => () => debouncedPush?.flush(), [debouncedPush]);

  // Clicking Send blurs the editor first, so flushing on blur guarantees the
  // server has the latest body before the send event is processed.
  const handleBlur = React.useCallback(() => debouncedPush?.flush(), [debouncedPush]);

  if (onEditEvent && pushEvent && pushEventTo) {
    onEdit = (values) => (debouncedPush ?? pushEdit)(values);
  } else if (onEditEvent && typeof onEdit !== 'function') {
    // LiveReact initializes in two passes — first without pushEventTo.
    // No-op prevents TypeError if Slate normalization triggers onChange before second pass.
    onEdit = () => {};
  }

  // Merge linkContext into the command context. Memoized so the reference is stable across
  // renders (Editor's React.memo now compares commandContext) but changes when linkContext
  // arrives on the LiveReact second pass, forcing the editor to pick it up.
  const mergedCommandContext = React.useMemo(
    () => ({
      ...(commandContext ?? { projectSlug }),
      ...(linkContext ? { linkContext } : {}),
    }),
    [commandContext, projectSlug, linkContext],
  );

  return (
    <div className={classNames('rich-text-editor', fixedToolbar && 'fixed-toolbar', className)}>
      <ErrorBoundary>
        <Editor
          normalizerContext={normalizerContext}
          placeholder={placeholder}
          style={style}
          editMode={editMode}
          fixedToolbar={fixedToolbar}
          commandContext={mergedCommandContext}
          onEdit={onEdit}
          onBlur={debouncedPush ? handleBlur : undefined}
          value={value}
          textDirection={textDirection}
          onChangeTextDirection={onChangeTextDirection}
          toolbarInsertDescs={blockInsertOptions({
            type: allowBlockElements ? 'extended' : 'inline',
            onRequestMedia: onRequestMedia,
          })}
        >
          {children}
        </Editor>
      </ErrorBoundary>
    </div>
  );
};

export const RichTextEditorConnected: React.FC<Omit<Props, 'projectSlug' | 'editMode'>> = (
  props,
) => {
  const { editMode, projectSlug, onRequestMedia } = useAuthoringElementContext();
  return (
    <RichTextEditor
      editMode={editMode}
      projectSlug={projectSlug}
      onRequestMedia={onRequestMedia}
      {...props}
    />
  );
};

RichTextEditorConnected.defaultProps = {
  textDirection: 'ltr',
};
