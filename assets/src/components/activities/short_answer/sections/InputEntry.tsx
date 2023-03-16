import {
  makeRule,
  parseInputFromRule,
  Input,
  InputText,
  InputNumeric,
  InputRange,
} from 'data/activities/model/rules';
import { InputType } from 'components/activities/short_answer/schema';
import { Response } from 'components/activities/types';
import { useState } from 'react';
import React from 'react';
import { NumericInput } from 'components/activities/short_answer/sections/NumericInput';
import { TextInput } from 'components/activities/short_answer/sections/TextInput';
import { MathInput } from 'components/activities/short_answer/sections/MathInput';

interface InputProps {
  inputType: InputType;
  response: Response;
  onEditResponseRule: (id: string, rule: string) => void;
}

export const InputEntry: React.FC<InputProps> = ({ inputType, response, onEditResponseRule }) => {
  const [input, setInput] = useState(
    parseInputFromRule(response.rule).valueOrThrow(
      Error(`failed to parse input value from rule ${response.rule}`),
    ),
  );

  const onEditInput = (update: Input) => {
    setInput(update);
    onEditResponseRule(response.id, makeRule(update));
  };

  if (inputType === 'math') {
    return <MathInput input={input as InputText} onEditInput={onEditInput} />;
  }
  if (inputType === 'numeric' || inputType === 'vlabvalue') {
    return <NumericInput input={input as InputNumeric | InputRange} onEditInput={onEditInput} />;
  }
  return <TextInput input={input as InputText} onEditInput={onEditInput} />;
};
