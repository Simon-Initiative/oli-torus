import React from 'react';
import { RichText } from 'components/activities/types';
import { Editor } from 'components/editor/Editor';
import { getToolbarForResourceType } from 'components/resource/toolbar';
import { ProjectSlug } from 'data/types';
import { classNames } from 'utils/classNames';

type RichTextEditorProps = {
  projectSlug: ProjectSlug;
  editMode: boolean;
  className?: string,
  text: RichText;
  onEdit: (text: RichText) => void;
};
export const RichTextEditor = ({ editMode, className, text, onEdit, projectSlug }:
  React.PropsWithChildren<RichTextEditorProps>) => {

  return (
    <div className={classNames(['rich-text-editor', className])}>
      <Editor commandContext={{ projectSlug }} editMode={editMode} value={text} onEdit={onEdit}
        toolbarItems={getToolbarForResourceType(1)} />
    </div>
  );
};
