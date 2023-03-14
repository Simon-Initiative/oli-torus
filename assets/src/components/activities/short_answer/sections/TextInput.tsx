import { useAuthoringElementContext } from 'components/activities/AuthoringElementProvider';
import { InputText, textOperator } from 'data/activities/model/rules';
import React from 'react';

interface InputProps {
  onEditInput: (input: InputText) => void;
  input: InputText;
}
export const TextInput: React.FC<InputProps> = ({ input, onEditInput }) => {
  const { editMode } = useAuthoringElementContext();
  return (
    <div className="d-flex flex-md-row mb-2">
      <select
        disabled={!editMode}
        className="form-control mr-2 border"
        style={{ width: 250 }}
        value={input.operator}
        onChange={({ target: { value } }) => {
          onEditInput({
            ...input,
            operator: textOperator(value),
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
        onChange={(e) => onEditInput({ ...input, value: e.target.value })}
        value={input.value}
      />
    </div>
  );
};

const textOptions: { value: string; displayValue: string }[] = [
  { value: 'equals', displayValue: 'Equals exactly' },
  { value: 'iequals', displayValue: 'Equals ignoring case' },
  { value: 'contains', displayValue: 'Contains' },
  { value: 'notcontains', displayValue: "Doesn't Contain" },
  { value: 'regex', displayValue: 'Regex' },
];
