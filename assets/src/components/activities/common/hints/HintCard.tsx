import { Hint, RichText } from 'components/activities/types';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { Card } from 'components/misc/Card';
import { ID } from 'data/content/model';
import React from 'react';

export const HintCard: React.FC<{
  title: JSX.Element;
  placeholder: string;
  hint: Hint;
  updateOne: (id: ID, content: RichText) => void;
}> = ({ title, placeholder, hint, updateOne }) => {
  return (
    <Card.Card>
      <Card.Title>{title}</Card.Title>
      <Card.Content>
        <RichTextEditorConnected
          style={{ backgroundColor: 'white' }}
          placeholder={placeholder}
          text={hint.content}
          onEdit={(content) => updateOne(hint.id, content)}
        />
      </Card.Content>
    </Card.Card>
  );
};
