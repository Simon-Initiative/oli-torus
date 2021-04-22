import React from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { ModelEditorProps } from '../schema';
import { RichText } from '../../types';
import { Description } from 'components/misc/Description';
import { IconCorrect, IconIncorrect } from 'components/misc/Icons';
import { ProjectSlug } from 'data/types';
import { classNames } from 'utils/classNames';

interface FeedbackProps extends ModelEditorProps {
  onEditResponse: (id: string, content: RichText) => void;
  projectSlug: ProjectSlug;
}
export const Feedback = ({ onEditResponse, model, editMode, projectSlug }: FeedbackProps) => {
  const {
    authoring: { parts },
  } = model;

  const correctResponse = parts[0].responses.find((r) => r.score === 1);
  if (!correctResponse) {
    throw new Error('Correct response could not be found:' + JSON.stringify(parts));
  }
  const incorrectResponses = parts[0].responses.filter((r) => r.id !== correctResponse.id);

  return (
    <div className={'my-5 ' + classNames(['feedback'])}>
      <Heading
        title="Answer Choice Feedback"
        subtitle="Providing feedback when a student answers a
        question is one of the best ways to reinforce their understanding."
        id="feedback"
      />
      <div className="mb-3" key={correctResponse.id}>
        <Description>
          <IconCorrect /> Feedback for Correct Choice
        </Description>
        <RichTextEditor
          projectSlug={projectSlug}
          editMode={editMode}
          text={correctResponse.feedback.content}
          onEdit={(content) => onEditResponse(correctResponse.id, content)}
        />
      </div>
      {incorrectResponses.map((response, index) => (
        <div className="mb-3" key={response.id}>
          <Description>
            <IconIncorrect /> Feedback for Incorrect Choice {index + 1}
          </Description>
          <RichTextEditor
            projectSlug={projectSlug}
            key={response.id}
            editMode={editMode}
            text={response.feedback.content}
            onEdit={(content) => onEditResponse(response.id, content)}
          />
        </div>
      ))}
    </div>
  );
};
