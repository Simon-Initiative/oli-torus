import React, { useState } from 'react';
import { Heading } from 'components/misc/Heading';
import { RichTextEditor } from 'components/editor/RichTextEditor';
import { ModelEditorProps } from '../schema';
import { RichText, Response } from '../../types';
import { Description } from 'components/misc/Description';
import { IconCorrect } from 'components/misc/IconCorrect';
import { parseInputFromRule } from '../utils';

interface FeedbackProps extends ModelEditorProps {
  onEditResponse: (id: string, content: RichText) => void;
  onRemoveResponse: (id: string) => void;
  onAddResponse: () => void;
  onEditResponseRule: (id: string, rule: string) => void;
}

interface ItemProps extends FeedbackProps {
  response: Response;
}

export const Item = (props: ItemProps) => {

  const { response, editMode, onEditResponse } = props;
  const style = { marginTop: '5px', width: '90%', display: 'inline' };
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
      <React.Fragment>
        <IconCorrect /> Feedback for Correct Answer:
        <input type={props.model.inputType === 'numeric' ? 'number' : 'text'}
          className="form-control"
          onChange={(e: any) => setValue(e.target.value)}
          value={value}
          style={style} />
      </React.Fragment>
    );
  } else if (value === '.*') {
    details = (
      <React.Fragment>
        Feedback for any other Incorrect Answer
      </React.Fragment>
    );
  } else {
    details = (
      <React.Fragment>
        Feedback for Incorrect Answer:
        <input type={props.model.inputType === 'numeric' ? 'number' : 'text'}
          className="form-control"
          onChange={(e: any) => onEditRule(e.target.value)}
          value={value}
          style={style} />
        <button className="btn btn-sm" onClick={() => props.onRemoveResponse(response.id)}>
          <i style={{ color: '#55C273' }} className="material-icons-outlined icon">
            delete-forever
          </i>
        </button>
      </React.Fragment>
    );
  }

  return (
    <React.Fragment key={response.id}>
      <RichTextEditor
        editMode={editMode}
        text={response.feedback.content}
        onEdit={content => onEditResponse(response.id, content)}>
          <Description>
            {details}
          </Description>
      </RichTextEditor>
    </React.Fragment>
  );
};

export const Feedback = (props: FeedbackProps) => {

  const { model, editMode, onAddResponse } = props;
  const { authoring: { parts } } = model;

  return (
    <div style={{ margin: '2rem 0' }}>
      <Heading title="Feedback" subtitle="Providing feedback when a student answers a
        question is one of the best ways to reinforce their understanding." id="feedback" />

      {parts[0].responses.map((response: Response) =>
        <Item key={response.id} {...props} response={response} />)}

      <button className="btn btn-primary" disabled={!editMode} onClick={onAddResponse}>
        Add Feedback
      </button>
    </div>
  );
};
