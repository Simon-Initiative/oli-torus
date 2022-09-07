import {
  makeRule,
  parseInputFromRule,
  parseOperatorFromRule,
  RuleOperator,
} from 'data/activities/model/rules';
import { InputType } from 'components/activities/short_answer/schema';
import { Response } from 'components/activities/types';
import { useState } from 'react';
import React from 'react';
import { NumericInput } from 'components/activities/short_answer/sections/NumericInput';
import { TextInput } from 'components/activities/short_answer/sections/TextInput';
import { MathInput } from 'components/activities/short_answer/sections/MathInput';
import { valueOr } from 'utils/common';

interface InputProps {
  inputType: InputType;
  response: Response;
  onEditResponseRule: (id: string, rule: string) => void;
}

interface SingleState {
  operator: RuleOperator;
  input: string;
}

interface RangeState {
  operator: RuleOperator;
  input: [string, string];
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

  const state = { operator, input: valueOr(input, '') };

  if (inputType === 'math') {
    return <MathInput state={state as SingleState} setState={onEditRule} />;
  }
  if (inputType === 'numeric' || inputType === 'vlabvalue') {
    return <NumericInput state={state as SingleState} setState={onEditRule} />;
  }
  return <TextInput state={state as SingleState} setState={onEditRule} />;
};
