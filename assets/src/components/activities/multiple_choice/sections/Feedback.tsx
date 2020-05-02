import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/editor/RichTextEditor';
import { ModelEditorProps, RichText } from '../schema';
import { Description } from 'components/misc/Description';
import { IconCorrect } from 'components/misc/IconCorrect';

interface FeedbackProps extends ModelEditorProps {
  onEditFeedback: (id: number, content: RichText) => void;
}
export const Feedback = ({ onEditFeedback, model, editMode }: FeedbackProps) => {
  const { authoring: { feedback } } = model;

  const correctFeedback = feedback.find(f => f.score === 1);
  if (!correctFeedback) {
    throw new Error('Correct feedback could not be found:' + JSON.stringify(feedback));
  }
  const incorrectFeedback = feedback.filter(feedback => feedback.id !== correctFeedback.id);

  return (
    <div style={{ margin: '2rem 0' }}>
      <Heading title="Answer Choice Feedback" subtitle="Providing feedback when a student answers a
        question is one of the best ways to reinforce their understanding." id="feedback" />
      <React.Fragment key={correctFeedback.id}>
        <RichTextEditor editMode={editMode} text={correctFeedback.content}
          onEdit={content => onEditFeedback(correctFeedback.id, content)}>
            <Description><IconCorrect /> Feedback for Correct Answer</Description>
        </RichTextEditor>
      </React.Fragment>
      {incorrectFeedback.map((feedback, index) =>
        <RichTextEditor key={feedback.id} editMode={editMode} text={feedback.content}
          onEdit={content => onEditFeedback(feedback.id, content)}>
          <Description>Feedback for Common Misconception {index + 1}</Description>
        </RichTextEditor>)}
    </div>
  );
};
