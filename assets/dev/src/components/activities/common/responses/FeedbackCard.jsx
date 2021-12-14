import React from 'react';
import { RichTextEditorConnected } from 'components/content/RichTextEditor';
import { Card } from 'components/misc/Card';
export const FeedbackCard = ({ title, feedback, update, placeholder }) => {
    return (<Card.Card>
      <Card.Title>{title}</Card.Title>
      <Card.Content>
        <RichTextEditorConnected placeholder={placeholder === undefined ? 'Enter feedback' : placeholder} value={feedback.content} onEdit={(content) => update(feedback.id, content)}/>
      </Card.Content>
    </Card.Card>);
};
//# sourceMappingURL=FeedbackCard.jsx.map