import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { Editor } from 'components/editing/editor/Editor';
import { NormalizerContext } from 'components/editing/editor/normalizers/normalizer';
import { ProjectSlug } from 'data/types';
import React from 'react';
import { Descendant, Editor as SlateEditor, Operation } from 'slate';
import { classNames } from 'utils/classNames';
import { MediaItemRequest } from 'components/activities/types';
import { blockInsertOptions } from 'components/editing/toolbar/editorToolbar/blocks/blockInsertOptions';

type Props = {
  projectSlug: ProjectSlug;
  editMode: boolean;
  value: Descendant[];
  className?: string;
  placeholder?: string;
  style?: React.CSSProperties;
  commandContext?: CommandContext;
  normalizerContext?: NormalizerContext;
  onEdit: (value: Descendant[], editor: SlateEditor, operations: Operation[]) => void;
  onRequestMedia?: (request: MediaItemRequest) => Promise<string | boolean>;
};
export const RichTextEditor: React.FC<Props> = (props) => {
  // Support content persisted when RichText had a `model` property.
  const value = (props.value as any).model ? (props.value as any).model : props.value;

  return (
    <div className={classNames('rich-text-editor', props.className)}>
      <ErrorBoundary>
        <Editor
          normalizerContext={props.normalizerContext}
          placeholder={props.placeholder}
          style={props.style}
          editMode={props.editMode}
          commandContext={
            props.commandContext ?? { projectSlug: props.projectSlug, pageTitles: {} }
          }
          onEdit={props.onEdit}
          value={value}
          toolbarInsertDescs={blockInsertOptions({
            onRequestMedia: props.onRequestMedia,
          })}
        >
          {props.children}
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
