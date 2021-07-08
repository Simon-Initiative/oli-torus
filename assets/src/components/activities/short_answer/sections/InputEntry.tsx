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
import { NumericInput } from 'components/activities/short_answer/sections/NumericInput';
import { TextInput } from 'components/activities/short_answer/sections/TextInput';

interface InputProps {
  inputType: InputType;
  response: Response;
  onEditResponseRule: (id: string, rule: string) => void;
}

export const InputEntry: React.FC<InputProps> = ({ inputType, response, onEditResponseRule }) => {
  const [{ operator, input }, setState] = useState({
    input: parseInputFromRule(response.rule),
    operator: parseOperatorFromRule(response.rule),
  });

  const onEditRule = (inputState: { input: string | [string, string]; operator: RuleOperator }) => {
    setState(inputState);
    onEditResponseRule(response.id, makeRule(inputState.operator, inputState.input));
  };

  const shared = {
    state: { operator, input },
    setState: onEditRule,
  };

  if (inputType === 'numeric') {
    return <NumericInput {...shared} />;
  }
  return <TextInput {...shared} />;
};
