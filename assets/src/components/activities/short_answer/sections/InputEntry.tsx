import { useState } from 'react';
import React from 'react';
import { InputType } from 'components/activities/short_answer/schema';
import { MathInput } from 'components/activities/short_answer/sections/MathInput';
import { NumericInput } from 'components/activities/short_answer/sections/NumericInput';
import { TextInput } from 'components/activities/short_answer/sections/TextInput';
import { Response } from 'components/activities/types';
import { MatchConfig, MatchConfigs, MathExpressionMatchConfig } from 'data/activities/model/match';
import {
  numericInputFromMatchConfig,
  numericInputToMatchConfig,
} from 'data/activities/model/match_conversion';
import {
  Input,
  InputKind,
  InputNumeric,
  InputRange,
  InputText,
  makeRule,
  parseInputFromRule,
} from 'data/activities/model/rules';

interface InputProps {
  inputType: InputType;
  response: Response;
  onEditResponseRule: (id: string, rule: string) => void;
  onEditResponseMatchConfig?: (id: string, matchConfig: MatchConfig) => void;
}

const expectedFromMatchConfig = (matchConfig: MatchConfig | undefined) => {
  if (matchConfig?.type !== 'math_expression') return '';
  if (!('expected' in matchConfig.math)) return '';

  return matchConfig.math.expected ?? '';
};

const updateExpected = (
  matchConfig: MatchConfig | undefined,
  expected: string,
): MathExpressionMatchConfig => {
  if (matchConfig?.type !== 'math_expression') {
    return MatchConfigs.algebraicEquivalence(expected);
  }

  return {
    ...matchConfig,
    math: {
      ...matchConfig.math,
      expected,
    },
  };
};

export const InputEntry: React.FC<InputProps> = ({
  inputType,
  response,
  onEditResponseRule,
  onEditResponseMatchConfig,
}) => {
  const [input, setInput] = useState(() => {
    if (inputType === 'math_expression') {
      const numericInput = numericInputFromMatchConfig(response.matchConfig);
      if (numericInput) return numericInput;

      return {
        kind: InputKind.Text,
        operator: 'equals',
        value: expectedFromMatchConfig(response.matchConfig),
      } as InputText;
    }

    return parseInputFromRule(response.rule).valueOrThrow(
      Error(`failed to parse input value from rule ${response.rule}`),
    );
  });

  const onEditInput = (update: Input) => {
    setInput(update);

    if (inputType === 'math_expression' && onEditResponseMatchConfig) {
      onEditResponseMatchConfig(
        response.id,
        update.kind === InputKind.Numeric || update.kind === InputKind.Range
          ? numericInputToMatchConfig(update)
          : updateExpected(response.matchConfig, (update as InputText).value),
      );
      return;
    }

    onEditResponseRule(response.id, makeRule(update));
  };

  if (
    inputType === 'math_expression' &&
    (input.kind === InputKind.Numeric || input.kind === InputKind.Range)
  ) {
    return <NumericInput input={input as InputNumeric | InputRange} onEditInput={onEditInput} />;
  }

  if (inputType === 'math' || inputType === 'math_expression') {
    return <MathInput input={input as InputText} onEditInput={onEditInput} />;
  }
  if (inputType === 'numeric' || inputType === 'vlabvalue') {
    return <NumericInput input={input as InputNumeric | InputRange} onEditInput={onEditInput} />;
  }
  return <TextInput input={input as InputText} onEditInput={onEditInput} />;
};
