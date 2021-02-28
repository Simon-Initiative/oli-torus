import React, { useState } from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/content/RichTextEditor';
import { ModelEditorProps } from '../schema';
import { RichText, Response } from '../../types';
import { Description } from 'components/misc/Description';
import { IconCorrect, IconIncorrect } from 'components/misc/Icons';
import { ProjectSlug } from 'data/types';

interface FeedbackProps extends ModelEditorProps {
  onEditResponse: (id: string, content: RichText) => void;
  projectSlug: ProjectSlug;
}

interface ItemProps extends FeedbackProps {
  response: Response;
}

export const Item = (props: ItemProps) => {

  const { response, editMode, onEditResponse } = props;

  return (
    <div className="my-3" key={response.id}>
      <Description>
        {response.score === 1 ? <IconCorrect /> : <IconIncorrect/>}
        Feedback for {response.score === 1 ? "Correct" : "Incorrect"} Answer:
      </Description>
      <RichTextEditor
        projectSlug={props.projectSlug}
        editMode={editMode}
        text={response.feedback.content}
        onEdit={content => onEditResponse(response.id, content)}/>
    </div>
  );

};

export const Feedback = (props: FeedbackProps) => {

  const { model } = props;
  const { authoring: { parts } } = model;

  return (
    <div className="my-5">
      <Heading title="Feedback" subtitle="Providing feedback when a student answers a
        question is one of the best ways to reinforce their understanding." id="feedback" />

      {parts[0].responses.map((response: Response, index) =>
        <Item key={response.id} {...props} response={response} />)}
    </div>
  );
};
