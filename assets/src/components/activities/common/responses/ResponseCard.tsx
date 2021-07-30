import { ID } from 'data/content/model';
import React from 'react';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { Response, RichText } from 'components/activities/types';
import { Tooltip } from 'components/misc/Tooltip';
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
        <>
          {title}
          <Tooltip
            title={'Shown only when a student response matches this answer choice combination'}
          />
          <RemoveButtonConnected onClick={() => onRemove(response.id)} />
        </>
      </Card.Title>
      <Card.Content>
        {children}
        <RichTextEditorConnected
          placeholder="Enter feedback"
          text={response.feedback.content}
          onEdit={(content) => updateFeedback(response.feedback.id, content)}
        />
      </Card.Content>
    </Card.Card>
  );
};
