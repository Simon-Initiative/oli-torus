import { Hint } from 'components/activities/types';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { Card } from 'components/misc/Card';
import { ID } from 'data/content/model/other';
import React from 'react';
import { Descendant } from 'slate';

export const HintCard: React.FC<{
  title: JSX.Element;
  placeholder: string;
  hint: Hint;
  updateOne: (id: ID, content: Descendant[]) => void;
}> = ({ title, placeholder, hint, updateOne }) => {
  return (
    <Card.Card>
      <Card.Title>{title}</Card.Title>
      <Card.Content>
        <RichTextEditorConnected
          placeholder={placeholder}
          value={hint.content}
          onEdit={(content) => updateOne(hint.id, content)}
        />
      </Card.Content>
    </Card.Card>
  );
};
