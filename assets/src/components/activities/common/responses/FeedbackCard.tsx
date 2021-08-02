import { ID } from 'data/content/model';
import React from 'react';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { Feedback, RichText } from 'components/activities/types';
import { Card } from 'components/misc/Card';

export const FeedbackCard: React.FC<{
  feedback: Feedback;
  title: React.ReactNode;
  update: (id: ID, content: RichText) => void;
}> = ({ title, feedback, update }) => {
  return (
    <Card.Card>
      <Card.Title>{title}</Card.Title>
      <Card.Content>
        <RichTextEditorConnected
          placeholder="Enter feedback"
          text={feedback.content}
          onEdit={(content) => update(feedback.id, content)}
        />
      </Card.Content>
    </Card.Card>
  );
};
