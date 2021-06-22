import { ID } from 'data/content/model';
import React, { useMemo } from 'react';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { defaultWriterContext } from 'data/content/writers/context';
import { Choice, ChoiceId, Feedback, RichText } from 'components/activities/types';
import { Tooltip } from 'components/misc/Tooltip';
import { Card } from 'components/misc/Card';
import { DeliveryChoices } from 'components/activities/common/choices/delivery/DeliveryChoices';

export const ResponseFeedbackCard: React.FC<{
  title: React.ReactNode;
  feedback: Feedback;
  choices: Choice[];
  correctChoiceIds: ChoiceId[];
  toggleChoice: (id: ChoiceId) => void;
  updateFeedback: (id: ID, content: RichText) => void;
  unselectedIcon: React.ReactNode;
  selectedIcon: React.ReactNode;
}> = ({
  title,
  feedback,
  choices,
  toggleChoice,
  updateFeedback,
  correctChoiceIds,
  unselectedIcon,
  selectedIcon,
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
        </>
      </Card.Title>
      <Card.Content>
        <DeliveryChoices
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
          text={feedback.content}
          onEdit={(content) => updateFeedback(feedback.id, content)}
        />
      </Card.Content>
    </Card.Card>
  );
};
