import React, { useReducer, useEffect } from 'react';
import ReactDOM from 'react-dom';
import { AuthoringElement, AuthoringElementProps } from '../AuthoringElement';
import { ShortAnswerModelSchema, InputType } from './schema';
import * as ActivityTypes from '../types';
import { Stem } from '../common/Stem';
import { Feedback } from './sections/Feedback';
import { Hints } from '../common/Hints';
import { ShortAnswerActions, ShortAnswerReducer } from './reducer';


const inputs: { value: string, displayValue: string}[] = [
  { value: 'numeric', displayValue: 'Numeric' },
  { value: 'text', displayValue: 'Short Text' },
  { value: 'textarea', displayValue: 'Long Text' },
];

type InputTypeDropdownProps = {
  editMode: boolean;
  onChange: (inputType: InputType) => void;
  inputType: InputType
};
export const InputTypeDropdown = ({ onChange, editMode, inputType }: InputTypeDropdownProps) => {

  const handleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    onChange(e.target.value as InputType);
  };

  return (
    <div>
      <label htmlFor="question-type">Input Type</label>
      <select style={{ width: '200px' }}
        disabled={!editMode} className="form-control" value={inputType}
        onChange={handleChange} name="question-type" id="question-type">
        {inputs.map(option =>
          <option key={option.value} value={option.value}>
            {option.displayValue}
          </option>)}
      </select>
    </div>
  );
};


const ShortAnswer = (props: AuthoringElementProps<ShortAnswerModelSchema>) => {
  const [state, dispatch] = useReducer(ShortAnswerReducer, props.model);

  useEffect(() => {
    props.onEdit(state);
  }, [state]);

  const sharedProps = {
    model: state,
    editMode: props.editMode,
  };

  return (
    <div className="p-4 pl-5">
      <InputTypeDropdown
        editMode={props.editMode}
        inputType={props.model.inputType}
        onChange={inputType => dispatch(ShortAnswerActions.setInputType(inputType))}/>
      <Stem
        editMode={props.editMode}
        stem={state.stem}
        onEditStem={content => dispatch(ShortAnswerActions.editStem(content))} />
      <Feedback {...sharedProps}
        onAddResponse={() => dispatch(ShortAnswerActions.addResponse())}
        onRemoveResponse={id => dispatch(ShortAnswerActions.removeReponse(id))}
        onEditResponseRule={(id, rule) => dispatch(ShortAnswerActions.editRule(id, rule))}
        onEditResponse={(id, content) => dispatch(ShortAnswerActions.editFeedback(id, content))} />
      <Hints
        hints={state.authoring.parts[0].hints}
        editMode={props.editMode}
        onAddHint={() => dispatch(ShortAnswerActions.addHint())}
        onEditHint={(id, content) => dispatch(ShortAnswerActions.editHint(id, content))}
        onRemoveHint={id => dispatch(ShortAnswerActions.removeHint(id))} />
    </div>
  );
};

export class ShortAnswerAuthoring extends AuthoringElement<ShortAnswerModelSchema> {
  render(mountPoint: HTMLDivElement, props: AuthoringElementProps<ShortAnswerModelSchema>) {
    ReactDOM.render(<ShortAnswer {...props} />, mountPoint);
  }
}

const manifest = require('./manifest.json') as ActivityTypes.Manifest;
window.customElements.define(manifest.authoring.element, ShortAnswerAuthoring);
