import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { Card } from 'components/misc/Card';
import React from 'react';
export const HintCard = ({ title, placeholder, hint, updateOne }) => {
    return (<Card.Card>
      <Card.Title>{title}</Card.Title>
      <Card.Content>
        <RichTextEditorConnected placeholder={placeholder} value={hint.content} onEdit={(content) => updateOne(hint.id, content)}/>
      </Card.Content>
    </Card.Card>);
};
//# sourceMappingURL=HintCard.jsx.map