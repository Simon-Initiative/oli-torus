import { ID } from 'data/content/model';
import React from 'react';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { Response, RichText } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { RemoveButtonConnected } from 'components/activities/common/authoring/removeButton/RemoveButton';

export const ResponseCard: React.FC<{
  title: React.ReactNode;
  response: Response;
  updateFeedback: (id: ID, content: RichText) => void;
  onRemove: (responseId: ID) => void;
}> = ({ title, response, updateFeedback, onRemove, children }) => {
  return (
    <Card.Card>
      <Card.Title>
        <div className="d-flex justify-content-between w-100">
          {title}
          <div className="flex-grow-1"></div>
          <RemoveButtonConnected onClick={() => onRemove(response.id)} />
        </div>
      </Card.Title>
      <Card.Content>
        {children}
        <RichTextEditorConnected
          placeholder="Explain why the student might have arrived at this answer"
          text={response.feedback.content}
          onEdit={(content) => updateFeedback(response.feedback.id, content)}
        />
      </Card.Content>
    </Card.Card>
  );
};
