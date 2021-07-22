import React, { useState } from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { ModelEditorProps } from '../schema';
import { RichText, Feedback as FeedbackItem } from '../../types';
import { Description } from 'components/misc/Description';
import { Checkmark } from 'components/misc/icons/Checkmark';
import { Cross } from 'components/misc/icons/Cross';
import { ProjectSlug } from 'data/types';

interface FeedbackProps extends ModelEditorProps {
  onEditResponse: (score: number, content: RichText) => void;
  projectSlug: ProjectSlug;
  onRequestMedia: any;
}

interface ItemProps extends FeedbackProps {
  feedback: FeedbackItem;
  score: number;
  onRequestMedia: any;
}

export const Item = (props: ItemProps) => {
  const { feedback, score, editMode, onEditResponse } = props;

  return (
    <div className="my-3" key={feedback.id}>
      <Description>
        {score === 1 ? <Checkmark /> : <Cross />}
        Feedback for {score === 1 ? 'Correct' : 'Incorrect'} Answer:
      </Description>
      <RichTextEditor
        projectSlug={props.projectSlug}
        editMode={editMode}
        text={feedback.content}
        onRequestMedia={props.onRequestMedia}
        onEdit={(content) => onEditResponse(score, content)}
      />
    </div>
  );
};

export const Feedback = (props: FeedbackProps) => {
  const { model } = props;

  return (
    <div className="my-5">
      <Heading
        title="Feedback"
        subtitle="Providing feedback when a student answers a
        question is one of the best ways to reinforce their understanding."
        id="feedback"
      />

      {model.feedback.map((f: FeedbackItem, index) => (
        <Item key={index} {...props} feedback={f} score={index} />
      ))}
    </div>
  );
};
