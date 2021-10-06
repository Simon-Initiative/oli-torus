import { ID } from 'data/content/model';
import React from 'react';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { Response, RichText } from 'components/activities/types';
import { Card } from 'components/misc/Card';
import { RemoveButtonConnected } from 'components/activities/common/authoring/removeButton/RemoveButton';

interface Props {
  title: React.ReactNode;
  response: Response;
  updateFeedback: (responseId: ID, content: RichText) => void;
  removeResponse: (responseId: ID) => void;
}
export const ResponseCard: React.FC<Props> = (props) => {
  return (
    <Card.Card>
      <Card.Title>
        <div className="d-flex justify-content-between w-100">
          {props.title}
          <div className="flex-grow-1"></div>
          <RemoveButtonConnected onClick={() => props.removeResponse(props.response.id)} />
        </div>
      </Card.Title>
      <Card.Content>
        {props.children}
        <RichTextEditorConnected
          placeholder="Explain why the student might have arrived at this answer"
          text={props.response.feedback.content}
          onEdit={(content) => props.updateFeedback(props.response.id, content)}
        />
      </Card.Content>
    </Card.Card>
  );
};
