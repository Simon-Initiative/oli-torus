import { RichText, Stem } from 'components/activities/types';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import React from 'react';

interface Props {
  stem: Stem;
  onEdit: (text: RichText) => void;
}

export const StemAuthoring: React.FC<Props> = ({ stem, onEdit }) => {
  return (
    <div className="flex-grow-1 mb-4">
      <RichTextEditorConnected value={stem.content} onEdit={onEdit} placeholder="Question" />
    </div>
  );
};
