import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import React from 'react';
import { escapeInput, isOperator, RuleOperator, unescapeInput } from 'data/activities/model/rules';

interface SimpleNumericInputState {
  operator: RuleOperator;
  input: string;
}

interface SimpleNumericInputProps extends InputProps {
  state: SimpleNumericInputState;
}

const SimpleNumericInput: React.FC<SimpleNumericInputProps> = ({ state, setState }) => {
  const { editMode } = useAuthoringElementContext();

  return (
    <input
      disabled={!editMode}
      type="number"
      className="form-control"
      onChange={(e) => {
        setState({ input: escapeInput(e.target.value), operator: state.operator });
      }}
      value={unescapeInput(state.input)}
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

  return (
    <div className="d-flex flex-column d-md-flex flex-md-row align-items-center">
      <input
        disabled={!editMode}
        type="number"
        className="form-control"
        onChange={(e) => {
          const newValue = [escapeInput(e.target.value), state.input[1]] as [string, string];
          setState({ input: newValue, operator: state.operator });
        }}
        value={unescapeInput(state.input[0])}
      />
      <div className="mx-1">and</div>
      <input
        placeholder="Correct answer"
        disabled={!editMode}
        type="number"
        className="form-control"
        onChange={(e) => {
          const newValue = [state.input[0], escapeInput(e.target.value)] as [string, string];
          setState({ input: newValue, operator: state.operator });
        }}
        value={unescapeInput(state.input[1])}
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
const isRangeOperator = (op: RuleOperator) => op === 'btw' || op === 'nbtw';

export const NumericInput: React.FC<InputProps> = ({ setState, state }) => {
  const { editMode } = useAuthoringElementContext();

  return (
    <div className="d-flex flex-column flex-md-row mb-2">
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
      {isRangeOperator(state.operator) ? (
        <RangeNumericInput state={state as RangeNumericInputState} setState={setState} />
      ) : (
        <SimpleNumericInput state={state as SimpleNumericInputState} setState={setState} />
      )}
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
