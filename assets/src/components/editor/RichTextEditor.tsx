import React from 'react';
import { RichText } from 'components/activities/types';
import { Editor } from 'components/editor/Editor';
import { getToolbarForResourceType } from 'components/resource/toolbar';
import { ProjectSlug } from 'data/types';
import { ErrorBoundary } from 'components/common/ErrorBoundary';

type RichTextEditorProps = {
  projectSlug: ProjectSlug;
  editMode: boolean;
  text: RichText;
  onEdit: (text: RichText) => void;
};
export const RichTextEditor = ({ editMode, text, onEdit, children, projectSlug }:
  React.PropsWithChildren<RichTextEditorProps>) => {

  return (
    <React.Fragment>
      {children}
      <div style={{
        border: '1px solid #e5e5e5',
        borderRadius: '2px',
        color: '#666',
        padding: '10px',
        fontFamily: 'Inter',
        fontSize: '11px',
        margin: '4px 0 10px 0',
      }}>
        <ErrorBoundary>
          <Editor commandContext={{ projectSlug }} editMode={editMode} value={text} onEdit={onEdit}
            toolbarItems={getToolbarForResourceType(1)} />
        </ErrorBoundary>
      </div>
    </React.Fragment>
  );
};
