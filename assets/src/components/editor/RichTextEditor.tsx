import React from 'react';
import { RichText } from 'components/activities/types';
import { Editor } from 'components/editor/Editor';
import { getToolbarForResourceType } from 'components/editor/toolbars/insertion/InsertionToolbarItems';
import { ProjectSlug } from 'data/types';
import { ErrorBoundary } from 'components/common/ErrorBoundary';
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
      <ErrorBoundary>
        <Editor
          commandContext={{ projectSlug }}
          editMode={editMode}
          value={text.model}
          onEdit={(model, selection) => onEdit({ model, selection })}
          selection={text.selection}
          toolbarItems={getToolbarForResourceType(1)}
          toolbarPosition={{ top: -45 }} />
      </ErrorBoundary>
    </div>
  );
};
