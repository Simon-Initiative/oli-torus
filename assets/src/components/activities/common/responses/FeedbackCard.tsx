import React from 'react';
import { Descendant } from 'slate';
import { Feedback } from 'components/activities/types';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { Card } from 'components/misc/Card';
import { ID } from 'data/content/model/other';

export const FeedbackCard: React.FC<{
  feedback: Feedback;
  title: React.ReactNode;
  update: (id: ID, content: Descendant[]) => void;
  placeholder?: string;
  children: any;
}> = ({ title, feedback, update, placeholder, children }) => {
  return (
    <Card.Card>
      <Card.Title>{title}</Card.Title>
      <Card.Content>
        <RichTextEditorConnected
          placeholder={placeholder === undefined ? 'Enter feedback' : placeholder}
          value={feedback.content}
          onEdit={(content) => update(feedback.id, content)}
        />
        {children}
      </Card.Content>
    </Card.Card>
  );
};
