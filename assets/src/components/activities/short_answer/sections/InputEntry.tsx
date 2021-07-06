import {
  makeRule,
  parseInputFromRule,
  parseOperatorFromRule,
  RuleOperator,
} from 'components/activities/common/responses/authoring/rules';
import { InputType } from 'components/activities/short_answer/schema';
import { Response } from 'components/activities/types';
import { useState } from 'react';
import React from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { NumericInput } from 'components/activities/short_answer/sections/NumericInput';
import { TextInput } from 'components/activities/short_answer/sections/TextInput';

interface InputProps {
  inputType: InputType;
  response: Response;
  onEditResponseRule: (id: string, rule: string) => void;
}

export const InputEntry: React.FC<InputProps> = ({ inputType, response, onEditResponseRule }) => {
  const { editMode } = useAuthoringElementContext();

  type Input = string | [string, string];
  const [{ operator, input }, setState] = useState({
    input: parseInputFromRule(response.rule),
    operator: parseOperatorFromRule(response.rule),
  });

  const onEditRule = (inputState: { input: Input; operator: RuleOperator }) => {
    if (input !== '.*') {
      setState(inputState);
      onEditResponseRule(response.id, makeRule(inputState.operator, inputState.input));
    }
  };
  if (input === '.*') {
    return null;
  }

  const shared = {
    state: { operator, input },
    setState: onEditRule,
  };

  switch (inputType) {
    case 'numeric':
      return <NumericInput {...shared} />;
    case 'text':
      return <TextInput {...shared} />;
    case 'textarea':
      return (
        <textarea
          disabled={!editMode}
          className="form-control"
          onChange={(e) => onEditRule({ operator: operator, input: e.target.value })}
          value={input}
        />
      );
    default:
      throw new Error('Could not find input type: ' + inputType);
  }
};
