import React from 'react';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { RichText, Stem } from 'components/activities/types';

interface Props {
  stem: Stem;
  onEdit: (text: RichText) => void;
  editMode: boolean;
  projectSlug: string;
}

export const StemAuthoring: React.FC<Props> = ({ stem, onEdit, editMode, projectSlug }) => {
  return (
    <div className="flex-grow-1">
      <RichTextEditor
        editMode={editMode}
        projectSlug={projectSlug}
        style={{ padding: '16px', fontSize: '18px' }}
        text={stem.content}
        onEdit={onEdit}
        placeholder="Question"
      />
    </div>
  );
};
