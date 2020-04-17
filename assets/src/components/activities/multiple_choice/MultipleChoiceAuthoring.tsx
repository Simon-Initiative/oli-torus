import React from 'react';
import ReactDOM from 'react-dom';
import { TextEditor } from 'components/TextEditor';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { MultipleChoiceModelSchema } from './schema';

const MultipleChoice = (props: AuthoringElementProps<MultipleChoiceModelSchema>) => {

  const onStemEdit = (stem: string) => {
    const model = Object.assign({}, props.model, { stem });
    props.onEdit(model);
  };

  return (
    <div style={{ width: '100%', height: '100px', border: 'solid 1px gray' }}>
      <h2>Welcome to the multiple choice editor!</h2>
      <TextEditor showAffordances={true} model={props.model.stem}
        editMode={true} onEdit={onStemEdit} />
    </div>
  );
};

export class MultipleChoiceAuthoring extends AuthoringElement<MultipleChoiceModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<MultipleChoiceModelSchema>) {
    ReactDOM.render(<MultipleChoice {...props} />, mountPoint);
  }
}


import * as ActivityTypes from '../types';
const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, MultipleChoiceAuthoring);


