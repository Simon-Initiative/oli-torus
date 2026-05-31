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
  numericRepresentationForConfig,
} from 'components/activities/short_answer/utils';
import { Response } from 'components/activities/types';
import {
  MatchConfig,
  MathExpressionQuestionConfig,
  NumericTolerance,
} from 'data/activities/model/match';
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

type NumericAnswerKind = InputNumeric['operator'] | InputRange['operator'] | 'tol';

type NumericState = {
  kind: NumericAnswerKind;
  input: InputNumeric | InputRange;
  tolerance: NumericTolerance;
};

type FractionMatchMode = 'exact' | 'equivalent';

const numericKinds: { value: NumericAnswerKind; displayValue: string }[] = [
  { value: 'gt', displayValue: 'Greater than' },
  { value: 'gte', displayValue: 'Greater than or equal to' },
  { value: 'lt', displayValue: 'Less than' },
  { value: 'lte', displayValue: 'Less than or equal to' },
  { value: 'eq', displayValue: 'Equal to' },
  { value: 'tol', displayValue: 'Within tolerance' },
  { value: 'neq', displayValue: 'Not equal to' },
  { value: 'btw', displayValue: 'Between' },
  { value: 'nbtw', displayValue: 'Not between' },
];

const controlClassName =
  'form-control dark:border-gray-600 dark:bg-body-dark dark:text-body-color-dark dark:placeholder-gray-400 dark:disabled:bg-gray-800 dark:disabled:text-gray-500';

const defaultTolerance = (): NumericTolerance => ({ type: 'absolute', value: 0.01 });

const isConfiguredTolerance = (tolerance: NumericTolerance | undefined) =>
  tolerance !== undefined && tolerance.type !== 'none';

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

  if (kind === 'tol') {
    return {
      kind,
      input: numericInput('eq', value || 1),
      tolerance: isConfiguredTolerance(previous.tolerance)
        ? previous.tolerance
        : defaultTolerance(),
    };
  }

  if (isNumericKind(kind)) {
    return { kind, input: numericInput(kind, value || 1), tolerance: previous.tolerance };
  }

  if (isRangeKind(kind)) {
    return { kind, input: rangeInput(kind, value || 1), tolerance: previous.tolerance };
  }

  return previous;
};

const toleranceFromMatchConfig = (matchConfig: MatchConfig | undefined): NumericTolerance =>
  matchConfig?.type === 'math_expression' && matchConfig.math.mode === 'numeric'
    ? matchConfig.math.tolerance ?? { type: 'none' }
    : { type: 'none' };

const stateFromMatchConfig = (matchConfig: MatchConfig | undefined): NumericState | undefined => {
  const numeric = numericInputFromMatchConfig(matchConfig);
  const tolerance = toleranceFromMatchConfig(matchConfig);

  return numeric
    ? {
        kind:
          numeric.kind === InputKind.Numeric &&
          numeric.operator === 'eq' &&
          isConfiguredTolerance(tolerance)
            ? 'tol'
            : numeric.operator,
        input: numeric,
        tolerance,
      }
    : undefined;
};

const defaultNumericState = (): NumericState => ({
  kind: 'eq',
  input: numericInput('eq', 1),
  tolerance: { type: 'none' },
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
            tolerance: { type: 'none' },
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

const fractionMatchModeFromMatchConfig = (
  matchConfig: MatchConfig | undefined,
): FractionMatchMode =>
  matchConfig?.type === 'math_expression' &&
  matchConfig.math.mode === 'algebraic_equivalence' &&
  matchConfig.math.form?.type === 'fraction'
    ? 'equivalent'
    : 'exact';

const defaultQuestionType = (inputType: InputType): ShortAnswerQuestionType => {
  if (inputType === 'text' || inputType === 'textarea') return inputType;
  if (inputType === 'numeric') return 'numeric';
  if (inputType === 'math') return 'latex_direct';
  if (inputType === 'math_expression') return 'algebraic';
  return 'text';
};

type NumericToleranceSettingsProps = {
  tolerance: NumericTolerance;
  onChange: (tolerance: NumericTolerance) => void;
};

const toleranceValue = (
  tolerance: NumericTolerance,
  field: 'value' | 'absolute' | 'relative',
  fallback: number,
) => {
  if (field === 'value' && (tolerance.type === 'absolute' || tolerance.type === 'relative')) {
    return tolerance.value;
  }

  if (field === 'absolute' && tolerance.type === 'absolute_or_relative') {
    return tolerance.absolute;
  }

  if (field === 'absolute' && tolerance.type === 'absolute') {
    return tolerance.value;
  }

  if (field === 'relative' && tolerance.type === 'absolute_or_relative') {
    return tolerance.relative;
  }

  if (field === 'relative' && tolerance.type === 'relative') {
    return tolerance.value;
  }

  return fallback;
};

const NumericToleranceSettings: React.FC<NumericToleranceSettingsProps> = ({
  tolerance,
  onChange,
}) => {
  const { editMode } = useAuthoringElementContext();
  const activeTolerance = tolerance.type === 'none' ? defaultTolerance() : tolerance;

  const setFiniteValue = (update: (value: number) => NumericTolerance) => (value: string) => {
    const numericValue = Number(value);
    if (Number.isFinite(numericValue) && numericValue >= 0) {
      onChange(update(numericValue));
    }
  };

  const onSelectToleranceType: React.ChangeEventHandler<HTMLSelectElement> = ({
    target: { value },
  }) => {
    switch (value) {
      case 'relative':
        onChange({
          type: 'relative',
          value: toleranceValue(activeTolerance, 'relative', 0.01),
        });
        break;
      case 'absolute_or_relative':
        onChange({
          type: 'absolute_or_relative',
          absolute: toleranceValue(activeTolerance, 'absolute', 0.01),
          relative: toleranceValue(activeTolerance, 'relative', 0.01),
        });
        break;
      case 'absolute':
      default:
        onChange({
          type: 'absolute',
          value: toleranceValue(activeTolerance, 'absolute', 0.01),
        });
        break;
    }
  };

  return (
    <div className="mb-2 rounded border border-gray-200 bg-gray-50 p-3 text-body-color dark:border-gray-700 dark:bg-gray-800 dark:text-body-color-dark">
      <div className="d-flex flex-column flex-md-row gap-2">
        <select
          disabled={!editMode}
          className={controlClassName}
          value={activeTolerance.type}
          onChange={onSelectToleranceType}
          aria-label="Tolerance type"
        >
          <option value="absolute">Absolute tolerance</option>
          <option value="relative">Relative tolerance</option>
          <option value="absolute_or_relative">Absolute or relative tolerance</option>
        </select>
        {activeTolerance.type === 'absolute' && (
          <input
            disabled={!editMode}
            type="number"
            min="0"
            step="any"
            className={controlClassName}
            aria-label="Absolute tolerance"
            value={activeTolerance.value}
            onChange={({ target: { value } }) =>
              setFiniteValue((nextValue) => ({ type: 'absolute', value: nextValue }))(value)
            }
          />
        )}
        {activeTolerance.type === 'relative' && (
          <input
            disabled={!editMode}
            type="number"
            min="0"
            step="any"
            className={controlClassName}
            aria-label="Relative tolerance"
            value={activeTolerance.value}
            onChange={({ target: { value } }) =>
              setFiniteValue((nextValue) => ({ type: 'relative', value: nextValue }))(value)
            }
          />
        )}
        {activeTolerance.type === 'absolute_or_relative' && (
          <>
            <input
              disabled={!editMode}
              type="number"
              min="0"
              step="any"
              className={controlClassName}
              aria-label="Absolute tolerance"
              value={activeTolerance.absolute}
              onChange={({ target: { value } }) =>
                setFiniteValue((nextValue) => ({
                  ...activeTolerance,
                  absolute: nextValue,
                }))(value)
              }
            />
            <input
              disabled={!editMode}
              type="number"
              min="0"
              step="any"
              className={controlClassName}
              aria-label="Relative tolerance"
              value={activeTolerance.relative}
              onChange={({ target: { value } }) =>
                setFiniteValue((nextValue) => ({
                  ...activeTolerance,
                  relative: nextValue,
                }))(value)
              }
            />
          </>
        )}
      </div>
    </div>
  );
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
  const [fractionMatchMode, setFractionMatchMode] = useState<FractionMatchMode>(() =>
    fractionMatchModeFromMatchConfig(response.matchConfig),
  );

  useEffect(() => {
    if (isNumericQuestion(inputType, activeQuestionType)) {
      setNumericState(numericStateFromResponse(response));
      return;
    }

    if (isMathExpressionQuestionType(activeQuestionType) || inputType === 'math') {
      setMathTextState(textInput(expectedAnswerFromResponse(response)));
      setMatchWrongUnits(matchConfigMatchesWrongUnits(response.matchConfig));
      setFractionMatchMode(fractionMatchModeFromMatchConfig(response.matchConfig));
      return;
    }

    setTextInputState(textStateFromResponse(response));
  }, [responseShape, inputType, activeQuestionType, response]);

  const persistNumericState = (nextState: NumericState) => {
    const matchConfig = numericInputToMatchConfig(nextState.input, undefined, {
      representation: numericRepresentationForConfig(mathExpressionConfig),
      tolerance: nextState.kind === 'tol' ? nextState.tolerance : { type: 'none' },
    });

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

  const onEditNumericTolerance = (tolerance: NumericTolerance) => {
    const nextState = { ...numericState, tolerance };
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

  const persistMathExpressionMatchConfig = (
    expected: string,
    matchWrongUnitsValue: boolean,
    fractionMatchValue: FractionMatchMode,
  ) => {
    if (onEditResponseMatchConfig && isMathExpressionQuestionType(activeQuestionType)) {
      onEditResponseMatchConfig(
        response.id,
        mathExpressionMatchConfigForQuestionType(
          activeQuestionType,
          expected,
          mathExpressionConfig,
          {
            matchWrongUnits: matchWrongUnitsValue,
            fractionMatch: fractionMatchValue,
          },
        ),
      );
      return;
    }

    onEditResponseRule(response.id, makeRule(textInput(expected)));
  };

  const onEditMathTextInput = (update: InputText) => {
    setMathTextState(update);

    persistMathExpressionMatchConfig(update.value, matchWrongUnits, fractionMatchMode);
  };

  const onToggleMatchWrongUnits = (checked: boolean) => {
    setMatchWrongUnits(checked);
    persistMathExpressionMatchConfig(mathTextState.value, checked, fractionMatchMode);
  };

  const onSelectFractionMatchMode: React.ChangeEventHandler<HTMLSelectElement> = ({
    target: { value },
  }) => {
    const nextMode = value as FractionMatchMode;
    setFractionMatchMode(nextMode);
    persistMathExpressionMatchConfig(mathTextState.value, matchWrongUnits, nextMode);
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
              className={`${controlClassName} mr-3`}
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
          {numericState.kind === 'tol' && (
            <NumericToleranceSettings
              tolerance={numericState.tolerance}
              onChange={onEditNumericTolerance}
            />
          )}
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
      <label className="d-flex align-items-center mt-2 mb-0 text-body-color dark:text-body-color-dark">
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

  const fractionMatchControl =
    activeQuestionType === 'fraction' ? (
      <div className="mt-2 rounded border border-gray-200 bg-gray-50 p-3 text-body-color dark:border-gray-700 dark:bg-gray-800 dark:text-body-color-dark">
        <select
          disabled={!editMode}
          className={controlClassName}
          value={fractionMatchMode}
          onChange={onSelectFractionMatchMode}
          aria-label="Fraction match type"
        >
          <option value="exact">Match this answer exactly</option>
          <option value="equivalent">Match equivalent fractions</option>
        </select>
      </div>
    ) : null;

  return (
    <div className="mb-2">
      <input
        disabled={!editMode}
        type="text"
        className={controlClassName}
        placeholder="Correct answer"
        value={mathTextState.value}
        onChange={({ target: { value } }) => onEditMathTextInput(textInput(value))}
      />
      {fractionMatchControl}
      {unitMismatchTargetControl}
    </div>
  );
};
