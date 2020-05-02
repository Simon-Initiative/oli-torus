import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/editor/RichTextEditor';
import { ModelEditorProps, RichText } from '../schema';

interface StemProps extends ModelEditorProps {
  onEditStem: (stem: RichText) => void;
}
export const Stem = ({ model, onEditStem, editMode }: StemProps) => {
  return (
    <div style={{ margin: '2rem 0' }}>
      <Heading title="Stem" subtitle="If students have learned the skills you're targeting,
        they should be able to answer this question:" id="stem" />
      <RichTextEditor
        editMode={editMode}
        text={model.stem.content}
        onEdit={onEditStem}
      />
    </div>
  );
};
