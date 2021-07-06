import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import React from 'react';
import { isOperator, RuleOperator } from 'components/activities/common/responses/authoring/rules';

const SimpleNumericInput: React.FC<InputProps> = ({ state, setState }) => {
  const { editMode } = useAuthoringElementContext();

  if (isRangeOperator(state.operator) || typeof state.input !== 'string') {
    return null;
  }

  return (
    <input
      disabled={!editMode}
      type="number"
      className="form-control"
      onChange={(e) => {
        setState({ input: e.target.value, operator: state.operator });
      }}
      value={state.input}
    />
  );
};

const RangeNumericInput: React.FC<InputProps> = ({ state, setState }) => {
  const { editMode } = useAuthoringElementContext();

  if (!isRangeOperator(state.operator) || typeof state.input === 'string') {
    return null;
  }

  return (
    <>
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
      <input
        placeholder="Correct answer"
        disabled={!editMode}
        type="number"
        className="form-control"
        onChange={(e) => {
          const newValue = [state.input[0], e.target.value] as [string, string];
          setState({ input: newValue, operator: state.operator });
        }}
        value={state.input[1]}
      />
    </>
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
const isRangeOperator = (op: RuleOperator) => op === 'btw' || op === 'nbtw';

export const NumericInput: React.FC<InputProps> = ({ setState, state }) => {
  const { editMode } = useAuthoringElementContext();

  const shared = {
    state,
    setState,
  };

  return (
    <div className="d-flex">
      <select
        disabled={!editMode}
        className="form-control"
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

          setState({ operator: nextOp, input: nextValue });
        }}
        name="question-type"
      >
        {numericOptions.map((option) => (
          <option key={option.value} value={option.value}>
            {option.displayValue}
          </option>
        ))}
      </select>
      <RangeNumericInput {...shared} />
      <SimpleNumericInput {...shared} />
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
