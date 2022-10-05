import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import React, { createRef, useRef, useState } from 'react';
import { isOperator, RuleOperator } from 'data/activities/model/rules';
import guid from 'utils/guid';
import { classNames } from 'utils/classNames';
import { disableScrollWheelChange } from '../utils';

interface SimpleNumericInputState {
  operator: RuleOperator;
  input: string;
}

interface SimpleNumericInputProps extends InputProps {
  state: SimpleNumericInputState;
}

const SimpleNumericInput: React.FC<SimpleNumericInputProps> = ({ state, setState }) => {
  const { editMode } = useAuthoringElementContext();

  const [value, _] = parseValueAndPrecision(state.input);

  return (
    <input
      disabled={!editMode}
      type="number"
      className="form-control"
      onChange={(e) => {
        setState({ input: e.target.value, operator: state.operator });
      }}
      value={value}
    />
  );
};

interface RangeNumericInputState {
  operator: RuleOperator;
  input: [string, string];
}

interface RangeNumericInputProps extends InputProps {
  state: RangeNumericInputState;
}

const RangeNumericInput: React.FC<RangeNumericInputProps> = ({ state, setState }) => {
  const { editMode } = useAuthoringElementContext();
  const numericInputRef = createRef<HTMLInputElement>();

  return (
    <div className="d-flex flex-column d-md-flex flex-md-row align-items-center">
      <input
        disabled={!editMode}
        type="number"
        className="form-control"
        onChange={(e) => {
          const newValue = [e.target.value, state.input[1]] as [string, string];
          setState({ input: newValue, operator: state.operator });
        }}
        value={state.input[0]}
      />
      <div className="mx-1">and</div>
      <input
        ref={numericInputRef}
        placeholder="Correct answer"
        disabled={!editMode}
        type="number"
        className="form-control"
        onChange={(e) => {
          const newValue = [state.input[0], e.target.value] as [string, string];
          setState({ input: newValue, operator: state.operator });
        }}
        value={state.input[1]}
        onWheel={disableScrollWheelChange(numericInputRef)}
      />
    </div>
  );
};

interface State {
  operator: RuleOperator;
  input: string | [string, string];
}

interface InputProps {
  setState: (s: State) => void;
  state: State;
}

export enum PrecisionKind {
  None,
  Invalid,
  WithPrecision,
}

export interface NoPrecision {
  kind: PrecisionKind.None;
}

export interface InvalidPrecision {
  kind: PrecisionKind.Invalid;
  value: string;
}

export interface WithPrecision {
  kind: PrecisionKind.WithPrecision;
  value: string;
}

export type Precision = NoPrecision | InvalidPrecision | WithPrecision;

const isRangeOperator = (op: RuleOperator) => op === 'btw' || op === 'nbtw';

export const validatePrecision = (value: string): Precision =>
  value.length > 0 && Number.isInteger(parseInt(value)) && parseInt(value) > 0
    ? { kind: PrecisionKind.WithPrecision, value }
    : { kind: PrecisionKind.Invalid, value };

const parseValueAndPrecision = (
  input: string | [string, string],
): [string | [string, string], Precision] => {
  if (Array.isArray(input)) return [input, { kind: PrecisionKind.None }];

  const [v, p] = input.split('#');

  switch (true) {
    case p && p.length > 0:
      return [v, { kind: PrecisionKind.WithPrecision, value: p }];
    default:
      return [v, { kind: PrecisionKind.None }];
  }
};

const numberOrEmptyString = (num: number) => (isNaN(num) ? '' : num);

const precisionInputValue = (precision: Precision) => {
  switch (precision.kind) {
    case PrecisionKind.WithPrecision:
    case PrecisionKind.Invalid:
      return numberOrEmptyString(parseInt(precision.value));
    default:
      return '';
  }
};

const composeInput = (
  value: string | [string, string],
  precision: Precision,
): string | [string, string] => {
  if (Array.isArray(value)) return value;

  switch (precision.kind) {
    case PrecisionKind.WithPrecision:
      return `${value}#${precision.value}`;
    default:
      return value;
  }
};

export const NumericInput: React.FC<InputProps> = ({ setState, state }) => {
  const { editMode } = useAuthoringElementContext();
  const numericInputRef = createRef<HTMLInputElement>();
  const [inputValue, p]: [string | [string, string], Precision] = parseValueAndPrecision(
    state.input,
  );
  const [precision, setPrecision] = useState(p);
  const precisionEdit = precision.kind !== PrecisionKind.None;

  const onTogglePrecision = () => {
    if (precisionEdit) {
      setPrecision({ kind: PrecisionKind.None });
    } else {
      const DEFAULT_PRECISION = '3';
      const p = { kind: PrecisionKind.WithPrecision, value: DEFAULT_PRECISION };
      setPrecision(p);
      setState({ ...state, input: composeInput(inputValue, p) });
    }
  };

  const onEditPrecision: React.ChangeEventHandler<HTMLInputElement> = ({ target: { value } }) => {
    const p = validatePrecision(value);
    setPrecision(p);

    if (p.kind !== PrecisionKind.Invalid) {
      setState({ ...state, input: composeInput(inputValue, p) });
    }
  };

  const precisionCheckboxId = `checkbox-${guid()}`;
  const precisionInvalid = precision.kind === PrecisionKind.Invalid;

  return (
    <div className="mb-2">
      <div className="d-flex flex-row">
        <select
          disabled={!editMode}
          className="form-control mr-1"
          value={state.operator}
          onChange={(e) => {
            const nextOp = e.target.value;
            if (!isOperator(nextOp)) {
              return;
            }

            let nextValue;
            if (isRangeOperator(nextOp) && !isRangeOperator(state.operator)) {
              nextValue = [state.input, state.input] as [string, string];
            } else if (isRangeOperator(state.operator) && !isRangeOperator(nextOp)) {
              nextValue = state.input[0];
            } else {
              nextValue = state.input;
            }

            setState({ operator: nextOp, input: composeInput(nextValue, precision) });
          }}
          name="question-type"
        >
          {numericOptions.map((option) => (
            <option key={option.value} value={option.value}>
              {option.displayValue}
            </option>
          ))}
        </select>
        {isRangeOperator(state.operator) ? (
          <RangeNumericInput state={state as RangeNumericInputState} setState={setState} />
        ) : (
          <div>
            <SimpleNumericInput state={state as SimpleNumericInputState} setState={setState} />

            <div className="d-flex flex-column">
              <div className="d-flex flex-row my-3">
                <div className="flex-grow-1"></div>
                <div className="d-flex flex-row align-items-center">
                  <div className="custom-control custom-switch mr-2">
                    <input
                      type="checkbox"
                      className="custom-control-input"
                      id={precisionCheckboxId}
                      checked={precisionEdit}
                      onChange={onTogglePrecision}
                    />
                    <label className="custom-control-label" htmlFor={precisionCheckboxId}>
                      Precision
                    </label>
                  </div>
                  <input
                    ref={numericInputRef}
                    type="number"
                    className={classNames('form-control', precisionInvalid && 'is-invalid')}
                    style={{ width: 200 }}
                    disabled={!precisionEdit}
                    value={precisionInputValue(precision)}
                    onChange={onEditPrecision}
                    aria-label="Precision"
                    onWheel={disableScrollWheelChange(numericInputRef)}
                  />
                </div>
              </div>
              <div className="d-flex flex-row">
                <div className="flex-grow-1"></div>
                {precisionInvalid && (
                  <div>
                    <small className="text-danger">
                      Precision must be a number greater than zero
                    </small>
                  </div>
                )}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export const numericOptions: { value: RuleOperator; displayValue: string }[] = [
  { value: 'gt', displayValue: 'Greater than' },
  { value: 'gte', displayValue: 'Greater than or equal to' },
  { value: 'lt', displayValue: 'Less than' },
  { value: 'lte', displayValue: 'Less than or equal to' },
  { value: 'eq', displayValue: 'Equal to' },
  { value: 'neq', displayValue: 'Not equal to' },
  { value: 'btw', displayValue: 'Between' },
  { value: 'nbtw', displayValue: 'Not between' },
];
