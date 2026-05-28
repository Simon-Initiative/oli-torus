import React, { useEffect, useMemo, useState } from 'react';
import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { InputType } from 'components/activities/short_answer/schema';
import { MathInput } from 'components/activities/short_answer/sections/MathInput';
import {
  PrecisionInput,
  RangeNumericInput,
  SimpleNumericInput,
} from 'components/activities/short_answer/sections/NumericInput';
import { TextInput } from 'components/activities/short_answer/sections/TextInput';
import {
  ShortAnswerQuestionType,
  expectedAnswerFromResponse,
  isMathExpressionQuestionType,
  mathExpressionMatchConfigForQuestionType,
} from 'components/activities/short_answer/utils';
import { Response } from 'components/activities/types';
import { MatchConfig, MathExpressionQuestionConfig } from 'data/activities/model/match';
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
  questionType?: ShortAnswerQuestionType;
  mathExpressionConfig?: MathExpressionQuestionConfig;
  response: Response;
  onEditResponseRule: (id: string, rule: string) => void;
  onEditResponseMatchConfig?: (id: string, matchConfig: MatchConfig) => void;
  allowUnitMismatchTarget?: boolean;
}

type NumericAnswerKind = InputNumeric['operator'] | InputRange['operator'];

type NumericState = {
  kind: NumericAnswerKind;
  input: InputNumeric | InputRange;
};

const numericKinds: { value: NumericAnswerKind; displayValue: string }[] = [
  { value: 'gt', displayValue: 'Greater than' },
  { value: 'gte', displayValue: 'Greater than or equal to' },
  { value: 'lt', displayValue: 'Less than' },
  { value: 'lte', displayValue: 'Less than or equal to' },
  { value: 'eq', displayValue: 'Equal to' },
  { value: 'neq', displayValue: 'Not equal to' },
  { value: 'btw', displayValue: 'Between' },
  { value: 'nbtw', displayValue: 'Not between' },
];

const isNumericKind = (kind: NumericAnswerKind): kind is InputNumeric['operator'] =>
  kind === 'gt' ||
  kind === 'gte' ||
  kind === 'lt' ||
  kind === 'lte' ||
  kind === 'eq' ||
  kind === 'neq';

const isRangeKind = (kind: NumericAnswerKind): kind is InputRange['operator'] =>
  kind === 'btw' || kind === 'nbtw';

const textInput = (value: string, operator: InputText['operator'] = 'equals'): InputText => ({
  kind: InputKind.Text,
  operator,
  value,
});

const numericInput = (
  operator: InputNumeric['operator'],
  value: string | number = 1,
): InputNumeric => ({
  kind: InputKind.Numeric,
  operator,
  value,
});

const rangeInput = (operator: InputRange['operator'], value: string | number = 1): InputRange => ({
  kind: InputKind.Range,
  operator,
  lowerBound: value,
  upperBound: value,
  inclusive: true,
});

const expectedFromInput = (input: Input) => {
  if (input.kind === InputKind.Numeric) return String(input.value);
  if (input.kind === InputKind.Range) return String(input.lowerBound);
  return input.value;
};

const stateFromKind = (kind: NumericAnswerKind, previous: NumericState): NumericState => {
  const value = expectedFromInput(previous.input);

  if (isNumericKind(kind)) {
    return { kind, input: numericInput(kind, value || 1) };
  }

  if (isRangeKind(kind)) {
    return { kind, input: rangeInput(kind, value || 1) };
  }

  return previous;
};

const stateFromMatchConfig = (matchConfig: MatchConfig | undefined): NumericState | undefined => {
  const numeric = numericInputFromMatchConfig(matchConfig);

  return numeric
    ? {
        kind: numeric.operator,
        input: numeric,
      }
    : undefined;
};

const defaultNumericState = (): NumericState => ({
  kind: 'eq',
  input: numericInput('eq', 1),
});

const numericStateFromResponse = (response: Response): NumericState => {
  const matchConfigState = stateFromMatchConfig(response.matchConfig);
  if (matchConfigState) return matchConfigState;

  return parseInputFromRule(response.rule ?? '').caseOf({
    just: (input) =>
      input.kind === InputKind.Numeric || input.kind === InputKind.Range
        ? {
            kind: input.operator,
            input,
          }
        : defaultNumericState(),
    nothing: () => defaultNumericState(),
  });
};

const textStateFromResponse = (response: Response) =>
  parseInputFromRule(response.rule ?? '').caseOf({
    just: (input) => input,
    nothing: () => textInput(''),
  });

const isNumericQuestion = (inputType: InputType, questionType: ShortAnswerQuestionType) =>
  inputType === 'numeric' || questionType === 'numeric';

const isLatexQuestion = (inputType: InputType, questionType: ShortAnswerQuestionType) =>
  inputType === 'math' || questionType === 'latex_direct';

const isUnitQuestionType = (questionType: ShortAnswerQuestionType) =>
  questionType === 'number_with_units' || questionType === 'expression_with_units';

const matchConfigMatchesWrongUnits = (matchConfig: MatchConfig | undefined) =>
  matchConfig?.type === 'math_expression' &&
  matchConfig.math.mode === 'unit_aware' &&
  matchConfig.math.matchWrongUnits === true;

const defaultQuestionType = (inputType: InputType): ShortAnswerQuestionType => {
  if (inputType === 'text' || inputType === 'textarea') return inputType;
  if (inputType === 'numeric') return 'numeric';
  if (inputType === 'math') return 'latex_direct';
  if (inputType === 'math_expression') return 'algebraic';
  return 'text';
};

export const InputEntry: React.FC<InputProps> = ({
  inputType,
  questionType,
  mathExpressionConfig = {},
  response,
  onEditResponseRule,
  onEditResponseMatchConfig,
  allowUnitMismatchTarget = false,
}) => {
  const { editMode } = useAuthoringElementContext();
  const activeQuestionType = questionType ?? defaultQuestionType(inputType);
  const responseShape = useMemo(
    () =>
      `${response.id}:${inputType}:${activeQuestionType}:${response.rule ?? ''}:${JSON.stringify(
        response.matchConfig,
      )}`,
    [response.id, response.rule, response.matchConfig, inputType, activeQuestionType],
  );
  const [textInputState, setTextInputState] = useState(() => textStateFromResponse(response));
  const [numericState, setNumericState] = useState(() => numericStateFromResponse(response));
  const [mathTextState, setMathTextState] = useState(() =>
    textInput(expectedAnswerFromResponse(response)),
  );
  const [matchWrongUnits, setMatchWrongUnits] = useState(() =>
    matchConfigMatchesWrongUnits(response.matchConfig),
  );

  useEffect(() => {
    if (isNumericQuestion(inputType, activeQuestionType)) {
      setNumericState(numericStateFromResponse(response));
      return;
    }

    if (isMathExpressionQuestionType(activeQuestionType) || inputType === 'math') {
      setMathTextState(textInput(expectedAnswerFromResponse(response)));
      setMatchWrongUnits(matchConfigMatchesWrongUnits(response.matchConfig));
      return;
    }

    setTextInputState(textStateFromResponse(response));
  }, [responseShape, inputType, activeQuestionType, response]);

  const persistNumericState = (nextState: NumericState) => {
    const matchConfig = numericInputToMatchConfig(nextState.input);

    if (onEditResponseMatchConfig) {
      onEditResponseMatchConfig(response.id, matchConfig);
      return;
    }

    onEditResponseRule(response.id, makeRule(nextState.input));
  };

  const onEditTextInput = (update: Input) => {
    setTextInputState(update);
    onEditResponseRule(response.id, makeRule(update));
  };

  const onEditNumericInput = (update: InputNumeric | InputRange) => {
    const nextState = { ...numericState, input: update };
    setNumericState(nextState);
    persistNumericState(nextState);
  };

  const onSelectNumericKind: React.ChangeEventHandler<HTMLSelectElement> = ({
    target: { value },
  }) => {
    const nextState = stateFromKind(value as NumericAnswerKind, numericState);
    setNumericState(nextState);
    persistNumericState(nextState);
  };

  const persistMathExpressionMatchConfig = (expected: string, matchWrongUnitsValue: boolean) => {
    if (onEditResponseMatchConfig && isMathExpressionQuestionType(activeQuestionType)) {
      onEditResponseMatchConfig(
        response.id,
        mathExpressionMatchConfigForQuestionType(
          activeQuestionType,
          expected,
          mathExpressionConfig,
          { matchWrongUnits: matchWrongUnitsValue },
        ),
      );
      return;
    }

    onEditResponseRule(response.id, makeRule(textInput(expected)));
  };

  const onEditMathTextInput = (update: InputText) => {
    setMathTextState(update);

    persistMathExpressionMatchConfig(update.value, matchWrongUnits);
  };

  const onToggleMatchWrongUnits = (checked: boolean) => {
    setMatchWrongUnits(checked);
    persistMathExpressionMatchConfig(mathTextState.value, checked);
  };

  if (
    !isNumericQuestion(inputType, activeQuestionType) &&
    !isMathExpressionQuestionType(activeQuestionType)
  ) {
    return <TextInput input={textInputState as InputText} onEditInput={onEditTextInput} />;
  }

  if (isNumericQuestion(inputType, activeQuestionType)) {
    return (
      <div className="mb-2">
        <div className="d-flex flex-column">
          <div className="d-flex flex-md-row mb-2">
            <select
              disabled={!editMode}
              className="form-control mr-3"
              value={numericState.kind}
              onChange={onSelectNumericKind}
              name="answer-match-type"
            >
              {numericKinds.map((option) => (
                <option key={option.value} value={option.value}>
                  {option.displayValue}
                </option>
              ))}
            </select>
            {numericState.input.kind === InputKind.Numeric ? (
              <SimpleNumericInput input={numericState.input} onEditInput={onEditNumericInput} />
            ) : (
              <RangeNumericInput input={numericState.input} onEditInput={onEditNumericInput} />
            )}
          </div>
          <PrecisionInput input={numericState.input} onEditInput={onEditNumericInput} />
        </div>
      </div>
    );
  }

  if (isLatexQuestion(inputType, activeQuestionType)) {
    return <MathInput input={mathTextState} onEditInput={onEditMathTextInput} />;
  }

  const unitMismatchTargetControl =
    allowUnitMismatchTarget && isUnitQuestionType(activeQuestionType) ? (
      <label className="d-flex align-items-center mt-2 mb-0">
        <input
          disabled={!editMode}
          type="checkbox"
          className="mr-1"
          checked={matchWrongUnits}
          onChange={({ target: { checked } }) => onToggleMatchWrongUnits(checked)}
        />
        Wrong units
      </label>
    ) : null;

  return (
    <div className="mb-2">
      <input
        disabled={!editMode}
        type="text"
        className="form-control"
        placeholder="Correct answer"
        value={mathTextState.value}
        onChange={({ target: { value } }) => onEditMathTextInput(textInput(value))}
      />
      {unitMismatchTargetControl}
    </div>
  );
};
