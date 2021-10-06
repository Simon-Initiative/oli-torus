import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { RichText } from 'components/activities/types';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { CommandContext } from 'components/editing/commands/interfaces';
import { Editor } from 'components/editing/editor/Editor';
import { NormalizerContext } from 'components/editing/editor/normalizers/normalizer';
import { getToolbarForResourceType } from 'components/editing/toolbars/insertion/items';
import { ProjectSlug } from 'data/types';
import React from 'react';
import { Editor as SlateEditor, Operation } from 'slate';
import { ReactEditor } from 'slate-react';
import { classNames } from 'utils/classNames';

type Props = {
  projectSlug: ProjectSlug;
  editMode: boolean;
  className?: string;
  text: RichText;
  onEdit: (text: RichText, editor: SlateEditor & ReactEditor, operations: Operation[]) => void;
  placeholder?: string;
  onRequestMedia?: any;
  style?: React.CSSProperties;
  commandContext?: CommandContext;
  normalizerContext?: NormalizerContext;
};
export const RichTextEditor: React.FC<Props> = (props) => {
  return (
    <div className={classNames(['rich-text-editor', props.className])}>
      <ErrorBoundary>
        <Editor
          normalizerContext={props.normalizerContext}
          commandContext={
            props.commandContext ? props.commandContext : { projectSlug: props.projectSlug }
          }
          editMode={props.editMode}
          value={props.text.model}
          onEdit={(model, selection, editor, operations) =>
            props.onEdit({ model, selection }, editor, operations)
          }
          selection={props.text.selection}
          toolbarItems={getToolbarForResourceType(1, props.onRequestMedia)}
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
