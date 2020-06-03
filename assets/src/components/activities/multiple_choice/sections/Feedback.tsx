import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/editor/RichTextEditor';
import { ModelEditorProps } from '../schema';
import { RichText } from '../../types';
import { Description } from 'components/misc/Description';
import { IconCorrect } from 'components/misc/IconCorrect';
import { ProjectSlug } from 'data/types';

interface FeedbackProps extends ModelEditorProps {
  onEditResponse: (id: string, content: RichText) => void;
  projectSlug: ProjectSlug;
}
export const Feedback = ({ onEditResponse, model, editMode, projectSlug }: FeedbackProps) => {

  const { authoring: { parts } } = model;

  const correctResponse = parts[0].responses.find(r => r.score === 1);
  if (!correctResponse) {
    throw new Error('Correct response could not be found:' + JSON.stringify(parts));
  }
  const incorrectResponses = parts[0].responses
    .filter(r => r.id !== correctResponse.id);

  return (
    <div style={{ margin: '2rem 0' }}>
      <Heading title="Answer Choice Feedback" subtitle="Providing feedback when a student answers a
        question is one of the best ways to reinforce their understanding." id="feedback" />
      <React.Fragment key={correctResponse.id}>
        <RichTextEditor projectSlug={projectSlug}
          editMode={editMode} text={correctResponse.feedback.content}
          onEdit={content => onEditResponse(correctResponse.id, content)}>
            <Description><IconCorrect /> Feedback for Correct Answer</Description>
        </RichTextEditor>
      </React.Fragment>
      {incorrectResponses.map((response, index) =>
        <RichTextEditor projectSlug={projectSlug}
          key={response.id} editMode={editMode} text={response.feedback.content}
          onEdit={content => onEditResponse(response.id, content)}>
          <Description>Feedback for Common Misconception {index + 1}</Description>
        </RichTextEditor>)}
    </div>
  );
};
