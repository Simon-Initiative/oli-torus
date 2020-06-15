import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/editor/RichTextEditor';
import { RichText, Stem as StemType } from '../types';
import { ProjectSlug } from 'data/types';

interface StemProps {
  onEditStem: (stem: RichText) => void;
  stem: StemType;
  editMode: boolean;
  projectSlug: ProjectSlug;
}

export const Stem = ({ stem, onEditStem, editMode, projectSlug }: StemProps) => {
  return (
    <div>
      <Heading title="Question Stem" subtitle="If students have learned the skills you're targeting,
        they should be able to answer this question:" id="stem" />
      <RichTextEditor
        projectSlug={projectSlug}
        editMode={editMode}
        text={stem.content}
        onEdit={onEditStem}
      />
    </div>
  );
};
