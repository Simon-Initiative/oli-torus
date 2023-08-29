import React from 'react';
import { RichText, Stem } from 'components/activities/types';
import { SlateOrMarkdownEditor } from 'components/editing/SlateOrMarkdownEditor';
import { DEFAULT_EDITOR, EditorType, SMALL_EDITOR_HEIGHT } from 'data/content/resource';

interface Props {
  stem: Stem;
  onEdit: (text: RichText) => void;
  onChangeEditorType: (editorType: EditorType) => void;
  editMode: boolean;
  projectSlug: string;
}

export const StemAuthoring: React.FC<Props> = ({
  stem,
  onEdit,
  onChangeEditorType,
  editMode,
  projectSlug,
}) => {
  return (
    <div className="flex-grow-1 mb-4">
      <SlateOrMarkdownEditor
        editMode={editMode}
        allowBlockElements={true}
        projectSlug={projectSlug}
        placeholder="Question"
        content={stem.content}
        onEdit={onEdit}
        onEditorTypeChange={onChangeEditorType}
        editorType={stem.editor || DEFAULT_EDITOR}
        initialHeight={SMALL_EDITOR_HEIGHT}
      />
    </div>
  );
};
