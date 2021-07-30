import React from 'react';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { RichText, Stem } from 'components/activities/types';

interface Props {
  stem: Stem;
  onEdit: (text: RichText) => void;
}

export const StemAuthoring: React.FC<Props> = ({ stem, onEdit }) => {
  return (
    <div className="flex-grow-1">
      <RichTextEditorConnected
        text={stem.content}
        onEdit={onEdit}
        placeholder="Enter question"
      />
    </div>
  );
};
