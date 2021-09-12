import React from 'react';
import { RichText } from 'components/activities/types';
import { Editor } from 'components/editing/editor/Editor';
import { getToolbarForResourceType } from 'components/editing/toolbars/insertion/items';
import { ProjectSlug } from 'data/types';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
import { classNames } from 'utils/classNames';
import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { ReactEditor } from 'slate-react';
import { Editor as SlateEditor, Operation } from 'slate';
import { CommandContext } from 'components/editing/commands/interfaces';

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
};
export const RichTextEditor: React.FC<Props> = (props) => {
  return (
    <div className={classNames(['rich-text-editor', props.className])}>
      <ErrorBoundary>
        <Editor
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
