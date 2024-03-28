import React from 'react';
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
};
export const RichTextEditor: React.FC<Props> = ({
  projectSlug,
  editMode,
  value,
  className,
  placeholder,
  style,
  commandContext,
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
}) => {
  // Support content persisted when RichText had a `model` property.
  value = (value as any).model ? (value as any).model : value;

  // Support for rendering the component within a LiveView or a LiveComponent:
  // if onEditEvent is not null it means this react component is rendered within a LiveView or a live_component
  // using the React.component wrapper
  // If so, events need to be pushed back to the LiveView or the live_component (the optional onEditTarget is used to target the event to a live_component)

  if (onEditEvent && pushEvent && pushEventTo) {
    onEdit = (values) => {
      if (onEditTarget) {
        pushEventTo(onEditTarget, onEditEvent, { values: values });
      } else {
        pushEvent(onEditEvent, { values: values });
      }
    };
  }

  return (
    <div className={classNames('rich-text-editor', fixedToolbar && 'fixed-toolbar', className)}>
      <ErrorBoundary>
        <Editor
          normalizerContext={normalizerContext}
          placeholder={placeholder}
          style={style}
          editMode={editMode}
          fixedToolbar={fixedToolbar}
          commandContext={commandContext ?? { projectSlug: projectSlug }}
          onEdit={onEdit}
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
