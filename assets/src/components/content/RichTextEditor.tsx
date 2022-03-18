import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { CommandContext } from 'components/editing/elements/commands/interfaces';
import { Editor } from 'components/editing/editor/Editor';
import { NormalizerContext } from 'components/editing/editor/normalizers/normalizer';
import { ProjectSlug } from 'data/types';
import React from 'react';
import { Descendant, Editor as SlateEditor, Operation } from 'slate';
import { classNames } from 'utils/classNames';
import { getToolbarForContentType } from 'components/editing/toolbar/utils';

type Props = {
  projectSlug: ProjectSlug;
  editMode: boolean;
  className?: string;
  value: Descendant[];
  onEdit: (value: Descendant[], editor: SlateEditor, operations: Operation[]) => void;
  placeholder?: string;
  onRequestMedia?: any;
  style?: React.CSSProperties;
  commandContext?: CommandContext;
  normalizerContext?: NormalizerContext;
  preventLargeContent?: boolean;
};
export const RichTextEditor: React.FC<Props> = (props) => {
  // Support content persisted when RichText had a `model` property.
  const value = (props.value as any).model ? (props.value as any).model : props.value;

  return (
    <div className={classNames('rich-text-editor', props.className)}>
      <ErrorBoundary>
        <Editor
          normalizerContext={props.normalizerContext}
          commandContext={props.commandContext || { projectSlug: props.projectSlug }}
          editMode={props.editMode}
          value={value}
          onEdit={(value, editor, operations) => props.onEdit(value, editor, operations)}
          toolbarInsertDescs={getToolbarForContentType({
            type: 'small',
            onRequestMedia: props.onRequestMedia,
          })}
          placeholder={props.placeholder}
          style={props.style}
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
      {...props}
      editMode={editMode}
      projectSlug={projectSlug}
      onRequestMedia={onRequestMedia}
    />
  );
};
