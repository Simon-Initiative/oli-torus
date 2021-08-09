import { useAuthoringElementContext } from 'components/activities/AuthoringElement';
import { isOperator, RuleOperator } from 'components/activities/common/responses/authoring/rules';
import React from 'react';

interface State {
  operator: RuleOperator;
  input: string | [string, string];
}
interface InputProps {
  setState: (s: State) => void;
  state: State;
}
export const TextInput: React.FC<InputProps> = ({ state, setState }) => {
  const { editMode } = useAuthoringElementContext();
  return (
    <div className="d-flex flex-md-row mb-2">
      <select
        disabled={!editMode}
        className="form-control mr-2"
        style={{ width: 250 }}
        value={state.operator}
        onChange={(e) => {
          if (!isOperator(e.target.value)) {
            return;
          }

          setState({
            operator: e.target.value,
            input: state.input,
          });
        }}
        name="question-type"
      >
        {textOptions.map((option) => (
          <option key={option.value} value={option.value}>
            {option.displayValue}
          </option>
        ))}
      </select>
      <input
        placeholder="Correct answer"
        disabled={!editMode}
        type="text"
        className="form-control"
        onChange={(e) => setState({ operator: state.operator, input: e.target.value })}
        value={state.input}
      />
    </div>
  );
};

const textOptions: { value: string; displayValue: string }[] = [
  { value: 'contains', displayValue: 'Contains' },
  { value: 'notcontains', displayValue: "Doesn't Contain" },
  { value: 'regex', displayValue: 'Regex' },
];
