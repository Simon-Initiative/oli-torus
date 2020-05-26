import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/editor/RichTextEditor';
import { ModelEditorProps } from '../multiple_choice/schema';
import { RichText, Stem as StemType } from '../types';

interface StemProps {
  onEditStem: (stem: RichText) => void;
  stem: StemType;
  editMode: boolean;
}
export const Stem = ({ stem, onEditStem, editMode }: StemProps) => {
  return (
    <div style={{ margin: '2rem 0' }}>
      <Heading title="Stem" subtitle="If students have learned the skills you're targeting,
        they should be able to answer this question:" id="stem" />
      <RichTextEditor
        editMode={editMode}
        text={stem.content}
        onEdit={onEditStem}
      />
    </div>
  );
};
