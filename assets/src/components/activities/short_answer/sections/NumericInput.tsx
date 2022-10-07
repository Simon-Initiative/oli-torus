import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import React, { createRef, useState } from 'react';
import {
  InputKind,
  InputNumeric,
  InputRange,
  numericOperator,
  rangeOperator,
  RuleOperator,
} from 'data/activities/model/rules';
import guid from 'utils/guid';
import { classNames } from 'utils/classNames';
import { disableScrollWheelChange } from '../utils';

export enum EditableNumberKind {
  Invalid,
  Valid,
}

export interface InvalidNumber {
  kind: EditableNumberKind.Invalid;
  value: number | '';
}

export interface ValidNumber {
  kind: EditableNumberKind.Valid;
  value: number;
}

export type EditableNumber = InvalidNumber | ValidNumber;

const parsedNumberOrEmptyString = (num: number | undefined) =>
  num != undefined && !isNaN(num) ? num : '';

const editableNumberFromNum = (num: number | undefined): EditableNumber =>
  num != undefined && !isNaN(num)
    ? { kind: EditableNumberKind.Valid, value: num }
    : { kind: EditableNumberKind.Invalid, value: parsedNumberOrEmptyString(num) };

const editableNumberFromString = (num: string): EditableNumber =>
  num.length > 0 && !isNaN(parseFloat(num))
    ? { kind: EditableNumberKind.Valid, value: parseFloat(num) }
    : { kind: EditableNumberKind.Invalid, value: parsedNumberOrEmptyString(parseFloat(num)) };

interface SimpleNumericInputProps extends InputProps {
  input: InputNumeric;
  onEditInput: (input: InputNumeric) => void;
}

const SimpleNumericInput: React.FC<SimpleNumericInputProps> = ({ input, onEditInput }) => {
  const { editMode } = useAuthoringElementContext();
  const numericInputRef = createRef<HTMLInputElement>();
  const [editableNumber, setEditableNumber] = useState(editableNumberFromNum(input.value));

  return (
    <input
      ref={numericInputRef}
      disabled={!editMode}
      type="number"
      className="form-control"
      onChange={({ target: { value } }) => {
        const newEditableNumber = editableNumberFromString(value);

        setEditableNumber(newEditableNumber);

        if (newEditableNumber.kind === EditableNumberKind.Valid) {
          onEditInput({ ...input, value: newEditableNumber.value });
        }
      }}
      value={editableNumber.value}
      onWheel={disableScrollWheelChange(numericInputRef)}
    />
  );
};

interface RangeNumericInputProps extends InputProps {
  input: InputRange;
  onEditInput: (input: InputRange) => void;
}

const RangeNumericInput: React.FC<RangeNumericInputProps> = ({ input, onEditInput }) => {
  const { editMode } = useAuthoringElementContext();
  const lowerBoundInputRef = createRef<HTMLInputElement>();
  const upperBoundInputRef = createRef<HTMLInputElement>();
  const [editableLowerBound, setEditableLowerBound] = useState(
    editableNumberFromNum(input.lowerBound),
  );
  const [editableUpperBound, setEditableUpperBound] = useState(
    editableNumberFromNum(input.upperBound),
  );
  const lowerBoundInvalid = editableLowerBound.kind === EditableNumberKind.Invalid;
  const upperBoundInvalid = editableUpperBound.kind === EditableNumberKind.Invalid;

  return (
    <div className="d-flex flex-column">
      <div className="d-md-flex flex-md-row align-items-center">
        <input
          ref={lowerBoundInputRef}
          disabled={!editMode}
          type="number"
          className="form-control"
          onChange={({ target: { value } }) => {
            const newEditableLowerBound = editableNumberFromString(value);

            setEditableLowerBound(newEditableLowerBound);

            if (newEditableLowerBound.kind === EditableNumberKind.Valid) {
              onEditInput({ ...input, lowerBound: newEditableLowerBound.value });
            }
          }}
          value={editableLowerBound.value}
          onWheel={disableScrollWheelChange(lowerBoundInputRef)}
        />
        <div className="mx-1">and</div>
        <input
          ref={upperBoundInputRef}
          placeholder="Correct answer"
          disabled={!editMode}
          type="number"
          className="form-control"
          onChange={({ target: { value } }) => {
            const editableUpperBound = editableNumberFromString(value);

            setEditableUpperBound(editableUpperBound);

            if (editableUpperBound.kind === EditableNumberKind.Valid) {
              onEditInput({ ...input, lowerBound: editableUpperBound.value });
            }
          }}
          value={editableUpperBound.value}
          onWheel={disableScrollWheelChange(upperBoundInputRef)}
        />
      </div>
      {lowerBoundInvalid && (
        <div className="d-flex flex-row">
          <div className="flex-grow-1"></div>
          <div>
            <small className="text-danger">Lower bound must be a valid number</small>
          </div>
        </div>
      )}
      {upperBoundInvalid && (
        <div className="d-flex flex-row">
          <div className="flex-grow-1"></div>
          <div>
            <small className="text-danger">Upper bound must be a valid number</small>
          </div>
        </div>
      )}
    </div>
  );
};

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
  value: number | '';
}

export interface WithPrecision {
  kind: PrecisionKind.WithPrecision;
  value: number;
}

export type Precision = NoPrecision | InvalidPrecision | WithPrecision;

export const validatePrecision = (value: string) =>
  value.length > 0 && !isNaN(parseInt(value)) && parseInt(value) > 0
    ? { kind: PrecisionKind.WithPrecision, value: parseInt(value) }
    : { kind: PrecisionKind.Invalid, value: numberOrEmptyString(parseInt(value)) };

const numberOrEmptyString = (num: number | '') => (num === '' || isNaN(num) ? '' : num);

const precisionInputValue = (precision: Precision) => {
  switch (precision.kind) {
    case PrecisionKind.WithPrecision:
    case PrecisionKind.Invalid:
      return numberOrEmptyString(precision.value);
    default:
      return '';
  }
};

const initialPrecision = (p: number | undefined): Precision =>
  p === undefined ? { kind: PrecisionKind.None } : { kind: PrecisionKind.WithPrecision, value: p };

interface PrecisionInputProps {
  input: InputNumeric | InputRange;
  onEditInput: (input: InputNumeric | InputRange) => void;
}

const PrecisionInput: React.FC<PrecisionInputProps> = ({ input, onEditInput }) => {
  const { editMode } = useAuthoringElementContext();
  const numericInputRef = createRef<HTMLInputElement>();
  const [precision, setPrecision] = useState(initialPrecision(input.precision));
  const precisionEdit = precision.kind !== PrecisionKind.None;
  const precisionInvalid = precision.kind === PrecisionKind.Invalid;

  const precisionCheckboxId = `checkbox-${guid()}`;

  const onTogglePrecision = () => {
    if (precisionEdit) {
      setPrecision({ kind: PrecisionKind.None });
      onEditInput({ ...input, precision: undefined });
    } else {
      const DEFAULT_PRECISION = 3;
      const p = { kind: PrecisionKind.WithPrecision, value: DEFAULT_PRECISION };
      setPrecision(p);
      onEditInput({ ...input, precision: p.value });
    }
  };

  const onEditPrecision: React.ChangeEventHandler<HTMLInputElement> = ({ target: { value } }) => {
    const p = validatePrecision(value);
    setPrecision(p as Precision);

    if (p.kind === PrecisionKind.WithPrecision) {
      onEditInput({ ...input, precision: (p as WithPrecision).value });
    }
  };

  return (
    <div className="d-flex flex-column">
      <div className="d-flex flex-row my-3">
        <div className="flex-grow-1"></div>
        <div className="d-flex flex-row align-items-center">
          <div className="custom-control custom-switch mr-2">
            <input
              type="checkbox"
              className="custom-control-input"
              disabled={!editMode}
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
            disabled={!editMode || !precisionEdit}
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
            <small className="text-danger">Precision must be a number greater than zero</small>
          </div>
        )}
      </div>
    </div>
  );
};
interface InputProps {
  onEditInput: (input: InputNumeric | InputRange) => void;
  input: InputNumeric | InputRange;
}

const isRangeOperator = (op: string) => op === 'btw' || op === 'nbtw';

export const operatorOptions: { value: RuleOperator; displayValue: string }[] = [
  { value: 'gt', displayValue: 'Greater than' },
  { value: 'gte', displayValue: 'Greater than or equal to' },
  { value: 'lt', displayValue: 'Less than' },
  { value: 'lte', displayValue: 'Less than or equal to' },
  { value: 'eq', displayValue: 'Equal to' },
  { value: 'neq', displayValue: 'Not equal to' },
  { value: 'btw', displayValue: 'Between' },
  { value: 'nbtw', displayValue: 'Not between' },
];

export const NumericInput: React.FC<InputProps> = ({ input, onEditInput }) => {
  const { editMode } = useAuthoringElementContext();

  const onSelectOperator: React.ChangeEventHandler<HTMLSelectElement> = (e) => {
    if (isRangeOperator(e.target.value)) {
      const nextOp = rangeOperator(e.target.value);
      // if we are switching from numeric operator to range, change the input
      // type and use the numeric value as the initial lower and upper bounds
      const nextInput = !isRangeOperator(input.operator)
        ? {
            kind: InputKind.Range,
            lowerBound: (input as InputNumeric).value,
            upperBound: (input as InputNumeric).value,
            precision: (input as InputNumeric).precision,
          }
        : (input as InputNumeric);
      onEditInput({ ...nextInput, operator: nextOp } as InputRange);
    } else {
      const nextOp = numericOperator(e.target.value);
      // if we are switching from range operator to numeric, change the input
      // type and use lower bound as initial value
      const nextInput = isRangeOperator(input.operator)
        ? {
            kind: InputKind.Numeric,
            value: (input as InputRange).lowerBound,
            precision: (input as InputRange).precision,
          }
        : (input as InputRange);
      onEditInput({ ...nextInput, operator: nextOp } as InputNumeric);
    }
  };

  return (
    <div className="mb-2">
      <div className="d-flex flex-row">
        <select
          disabled={!editMode}
          className="form-control mr-1"
          value={input.operator}
          onChange={onSelectOperator}
          name="question-type"
        >
          {operatorOptions.map((option) => (
            <option key={option.value} value={option.value}>
              {option.displayValue}
            </option>
          ))}
        </select>
        {isRangeOperator(input.operator) ? (
          <RangeNumericInput input={input as InputRange} onEditInput={onEditInput} />
        ) : (
          <div>
            <SimpleNumericInput input={input as InputNumeric} onEditInput={onEditInput} />
          </div>
        )}
      </div>
      <PrecisionInput input={input} onEditInput={onEditInput} />
    </div>
  );
};
