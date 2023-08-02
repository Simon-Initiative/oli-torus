import React from 'react';
import { Descendant } from 'slate';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';
import { Response } from 'components/activities/types';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { Card } from 'components/misc/Card';
import CustomCheckbox from 'apps/authoring/components/PropertyEditor/custom/CustomCheckbox';
import { ID } from 'data/content/model/other';

interface Props {
  title: React.ReactNode;
  response: Response;
  updateFeedback: (responseId: ID, content: Descendant[]) => void;
  updateCorrectness: (responseId: ID, correct: boolean) => void;
  removeResponse: (responseId: ID) => void;
}
export const ResponseCard: React.FC<Props> = (props) => {
  return (
    <Card.Card>
      <Card.Title>
        <div className="d-flex justify-content-between w-100">{props.title}</div>
        <div className="flex-grow-1"></div>
        <CustomCheckbox
          label="Correct&nbsp;"
          id={props.response.id + '-correct'}
          value={!!props.response.score}
          onChange={(value) => props.updateCorrectness(props.response.id, value)}
        />
        <RemoveButtonConnected onClick={() => props.removeResponse(props.response.id)} />
      </Card.Title>
      <Card.Content>
        <RichTextEditorConnected
          placeholder="Explain why the student might have arrived at this answer"
          value={props.response.feedback.content}
          onEdit={(content) => props.updateFeedback(props.response.id, content)}
        />
        {props.children}
      </Card.Content>
    </Card.Card>
  );
};
