import { ID } from 'data/content/model';
import React, { useMemo } from 'react';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { defaultWriterContext } from 'data/content/writers/context';
import { Choice, ChoiceId, Response, RichText } from 'components/activities/types';
import { Tooltip } from 'components/misc/Tooltip';
import { Card } from 'components/misc/Card';
import { ChoicesDelivery } from 'components/activities/common/choices/delivery/ChoicesDelivery';
import { RemoveButtonConnected } from 'components/activities/common/authoring/RemoveButton';

export const ResponseCard: React.FC<{
  title: React.ReactNode;
  response: Response;
  choices: Choice[];
  correctChoiceIds: ChoiceId[];
  toggleChoice: (id: ChoiceId) => void;
  updateFeedback: (id: ID, content: RichText) => void;
  unselectedIcon: React.ReactNode;
  selectedIcon: React.ReactNode;
  onRemove: (responseId: ID) => void;
}> = ({
  title,
  response,
  choices,
  toggleChoice,
  updateFeedback,
  correctChoiceIds,
  unselectedIcon,
  selectedIcon,
  onRemove,
}) => {
  const context = useMemo(defaultWriterContext, []);
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
        <ChoicesDelivery
          unselectedIcon={unselectedIcon}
          selectedIcon={selectedIcon}
          choices={choices}
          selected={correctChoiceIds}
          onSelect={toggleChoice}
          isEvaluated={false}
          context={context}
        />
        <RichTextEditorConnected
          style={{ backgroundColor: 'white' }}
          placeholder="Enter feedback"
          text={response.feedback.content}
          onEdit={(content) => updateFeedback(response.feedback.id, content)}
        />
      </Card.Content>
    </Card.Card>
  );
};
