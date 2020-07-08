import React, { useState } from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/editor/RichTextEditor';
import { ModelEditorProps } from '../schema';
import { RichText, Response } from '../../types';
import { Description } from 'components/misc/Description';
import { IconCorrect, IconIncorrect } from 'components/misc/Icons';
import { parseInputFromRule } from '../utils';
import { ProjectSlug } from 'data/types';

interface FeedbackProps extends ModelEditorProps {
  onEditResponse: (id: string, content: RichText) => void;
  onRemoveResponse: (id: string) => void;
  onAddResponse: () => void;
  onEditResponseRule: (id: string, rule: string) => void;
  projectSlug: ProjectSlug;
}

interface ItemProps extends FeedbackProps {
  response: Response;
}

export const Item = (props: ItemProps) => {

  const { response, editMode, onEditResponse } = props;
  let details;
  const [value, setValue] = useState(parseInputFromRule(response.rule));

  const onEditRule = (input: string) => {

    if (input !== '.*') {

      setValue(input);

      const rule = props.model.inputType === 'numeric'
        ? `input = {${input}}`
        : `input like {${input}}`;

      props.onEditResponseRule(response.id, rule);

    }

  };

  if (response.score === 1) {
    details = (
      <div className="my-2">
        <IconCorrect /> Feedback for Correct Answer:
        <input type={props.model.inputType === 'numeric' ? 'number' : 'text'}
          className="form-control my-2"
          placeholder="Enter correct answer..."
          onChange={(e: any) => onEditRule(e.target.value)}
          value={value} />
      </div>
    );
  } else if (value === '.*') {
    details = (
      <div className="my-2">
        <IconIncorrect /> Feedback for any other Incorrect Answer
      </div>
    );
  } else {
    details = (
      <div className="my-2">
        Feedback for Incorrect Answer:
        <input type={props.model.inputType === 'numeric' ? 'number' : 'text'}
          className="form-control"
          onChange={(e: any) => onEditRule(e.target.value)}
          value={value} />
        <button className="btn btn-sm" onClick={() => props.onRemoveResponse(response.id)}>
          <i style={{ color: '#55C273' }} className="material-icons-outlined icon">
            delete-forever
          </i>
        </button>
      </div>
    );
  }

  return (
    <React.Fragment key={response.id}>
      <Description>
        {details}
      </Description>
      <RichTextEditor
        projectSlug={props.projectSlug}
        editMode={editMode}
        text={response.feedback.content}
        onEdit={content => onEditResponse(response.id, content)}/>
    </React.Fragment>
  );
};

export const Feedback = (props: FeedbackProps) => {

  const { model, editMode, onAddResponse } = props;
  const { authoring: { parts } } = model;

  return (
    <div className="my-5">
      <Heading title="Feedback" subtitle="Providing feedback when a student answers a
        question is one of the best ways to reinforce their understanding." id="feedback" />

      {parts[0].responses.map((response: Response) =>
        <Item key={response.id} {...props} response={response} />)}

      <button className="btn btn-sm btn-primary my-2" disabled={!editMode} onClick={onAddResponse}>
        Add Feedback
      </button>
    </div>
  );
};
