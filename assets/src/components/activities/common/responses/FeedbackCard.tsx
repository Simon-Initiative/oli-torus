import React from 'react';
import { Descendant } from 'slate';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { Feedback } from 'components/activities/types';
import { SlateOrMarkdownEditor } from 'components/editing/SlateOrMarkdownEditor';
import { Card } from 'components/misc/Card';
import { TextDirection } from 'data/content/model/elements/types';
import { ID } from 'data/content/model/other';
import { DEFAULT_EDITOR, EditorType } from 'data/content/resource';

export const FeedbackCard: React.FC<{
  feedback: Feedback;
  title: React.ReactNode;
  update: (id: ID, content: Descendant[]) => void;
  updateEditor: (editor: EditorType) => void;
  updateTextDirection: (textDirection: TextDirection) => void;
  placeholder?: string;
  children: any;
  editMode?: boolean;
}> = ({ title, feedback, update, placeholder, children, updateEditor, updateTextDirection, editMode = true }) => {
  const { projectSlug } = useAuthoringElementContext();
  return (
    <Card.Card>
      <Card.Title>{title}</Card.Title>
      <Card.Content>
        <SlateOrMarkdownEditor
          placeholder={placeholder === undefined ? 'Enter feedback' : placeholder}
          content={feedback.content}
          onEdit={(content) => update(feedback.id, content)}
          onEditorTypeChange={updateEditor}
          editMode={editMode}
          editorType={feedback.editor || DEFAULT_EDITOR}
          allowBlockElements={true}
          projectSlug={projectSlug}
          textDirection={feedback.textDirection}
          onChangeTextDirection={updateTextDirection}
        />
        {/* <RichTextEditorConnected
          placeholder={placeholder === undefined ? 'Enter feedback' : placeholder}
          value={feedback.content}
          onEdit={(content) => update(feedback.id, content)}
        /> */}
        {children}
      </Card.Content>
    </Card.Card>
  );
};
