import React from 'react';
import { Descendant } from 'slate';
import { Hint } from 'components/activities/types';
import { SlateOrMarkdownEditor } from 'components/editing/SlateOrMarkdownEditor';
import { Card } from 'components/misc/Card';
import { ID } from 'data/content/model/other';
import { DEFAULT_EDITOR, EditorType } from 'data/content/resource';

export const HintCard: React.FC<{
  title: JSX.Element;
  placeholder: string;
  hint: Hint;
  updateOne: (id: ID, content: Descendant[]) => void;
  updateOneEditor: (id: ID, editor: EditorType) => void;
  updateOneTextDirection: (id: ID, textDirection: string) => void;
  projectSlug: string;
}> = ({
  title,
  placeholder,
  hint,
  updateOne,
  updateOneEditor,
  updateOneTextDirection,
  projectSlug,
}) => {
  return (
    <Card.Card>
      <Card.Title>
        <span style={{ fontWeight: 700, fontSize: '16px', lineHeight: '24px', color: '#353740' }}>
          {title}
        </span>
      </Card.Title>
      <Card.Content>
        <SlateOrMarkdownEditor
          placeholder={placeholder}
          content={hint?.content || []}
          onEdit={(content) => updateOne(hint.id, content)}
          editMode={true}
          editorType={hint.editor || DEFAULT_EDITOR}
          onEditorTypeChange={(editor) => updateOneEditor(hint.id, editor)}
          allowBlockElements={true}
          projectSlug={projectSlug}
          textDirection={hint.textDirection}
          onChangeTextDirection={(textDirection) => updateOneTextDirection(hint.id, textDirection)}
        />
      </Card.Content>
    </Card.Card>
  );
};
