import React, { useState } from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/editor/RichTextEditor';
import { ModelEditorProps } from '../schema';
import { RichText, Response } from '../../types';
import { Description } from 'components/misc/Description';
import { IconCorrect, IconIncorrect } from 'components/misc/Icons';
import { parseInputFromRule } from '../utils';
import { ProjectSlug } from 'data/types';
import { CloseButton } from 'components/misc/CloseButton';

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
    return (
      <div className="my-3" key={response.id}>
        <Description>
          <IconCorrect /> Feedback for Correct Answer:
          <input type={props.model.inputType === 'numeric' ? 'number' : 'text'}
            className="form-control my-2"
            placeholder="Enter correct answer..."
            onChange={(e: any) => onEditRule(e.target.value)}
            value={value} />
        </Description>
        <RichTextEditor
          projectSlug={props.projectSlug}
          editMode={editMode}
          text={response.feedback.content}
          onEdit={content => onEditResponse(response.id, content)}/>
      </div>
    );
  } else if (value === '.*') {
    return (
      <div className="my-3" key={response.id}>
        <Description>
          <IconIncorrect /> Feedback for any other Incorrect Answer
        </Description>
        <RichTextEditor
          projectSlug={props.projectSlug}
          editMode={editMode}
          text={response.feedback.content}
          onEdit={content => onEditResponse(response.id, content)}/>
      </div>
    );
  } else {
    return (
      <div className="my-3 d-flex mb-3" key={response.id}>
        <div className="d-flex flex-column flex-grow-1">
          <Description>
            <IconIncorrect /> Feedback for Incorrect Answer:
            <input type={props.model.inputType === 'numeric' ? 'number' : 'text'}
              className="form-control"
              onChange={(e: any) => onEditRule(e.target.value)}
              value={value} />
          </Description>
          <RichTextEditor
            projectSlug={props.projectSlug}
            editMode={editMode} text={response.feedback.content}
            onEdit={content => onEditResponse(response.id, content)}/>
        </div>
        <CloseButton
          className="pl-3 pr-1"
          onClick={() => props.onRemoveResponse(response.id)}
          editMode={editMode} />
      </div>
    );
  }
};

export const Feedback = (props: FeedbackProps) => {

  const { model, editMode, onAddResponse } = props;
  const { authoring: { parts } } = model;

  return (
    <div className="my-5">
      <Heading title="Feedback" subtitle="Providing feedback when a student answers a
        question is one of the best ways to reinforce their understanding." id="feedback" />

      {parts[0].responses.map((response: Response, index) =>
        <Item key={response.id} {...props} response={response} />)}

      <button className="btn btn-sm btn-primary my-2" disabled={!editMode} onClick={onAddResponse}>
        Add Feedback
      </button>
    </div>
  );
};
