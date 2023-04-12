import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { MediaItemRequest } from 'components/activities/types';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { Editor } from 'components/editing/editor/Editor';
import { NormalizerContext } from 'components/editing/editor/normalizers/normalizer';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { blockInsertOptions } from 'components/editing/toolbar/editorToolbar/blocks/blockInsertOptions';
import { ProjectSlug } from 'data/types';
import React from 'react';
import { Descendant, Operation, Editor as SlateEditor } from 'slate';
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
  onEdit: (value: Descendant[], editor: SlateEditor, operations: Operation[]) => void;
  onRequestMedia?: (request: MediaItemRequest) => Promise<string | boolean>;
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
}) => {
  // Support content persisted when RichText had a `model` property.
  value = (value as any).model ? (value as any).model : value;

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
