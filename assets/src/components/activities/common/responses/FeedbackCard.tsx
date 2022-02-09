import { ID } from 'data/content/model/other';
import React from 'react';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { Feedback } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { Descendant } from 'slate';

export const FeedbackCard: React.FC<{
  feedback: Feedback;
  title: React.ReactNode;
  update: (id: ID, content: Descendant[]) => void;
  placeholder?: string;
}> = ({ title, feedback, update, placeholder }) => {
  return (
    <Card.Card>
      <Card.Title>{title}</Card.Title>
      <Card.Content>
        <RichTextEditorConnected
          placeholder={placeholder === undefined ? 'Enter feedback' : placeholder}
          value={feedback.content}
          onEdit={(content) => update(feedback.id, content)}
        />
      </Card.Content>
    </Card.Card>
  );
};
