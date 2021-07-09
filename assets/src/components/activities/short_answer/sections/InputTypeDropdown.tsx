import React from 'react';

import { InputType, isInputType } from 'components/activities/short_answer/schema';

const inputs: { value: string; displayValue: string }[] = [
  { value: 'numeric', displayValue: 'Number' },
  { value: 'text', displayValue: 'Short Answer' },
  { value: 'textarea', displayValue: 'Paragraph' },
];

type InputTypeDropdownProps = {
  editMode: boolean;
  onChange: (inputType: InputType) => void;
  inputType: InputType;
};
export const InputTypeDropdown: React.FC<InputTypeDropdownProps> = ({
  onChange,
  editMode,
  inputType,
}) => {
  const handleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    if (!isInputType(e.target.value)) {
      return;
    }
    onChange(e.target.value);
  };

  return (
    <select
      style={{ height: 61, width: 150 }}
      disabled={!editMode}
      className="form-control ml-1"
      value={inputType}
      onChange={handleChange}
      name="question-type"
      id="question-type"
    >
      {inputs.map((option) => (
        <option key={option.value} value={option.value}>
          {option.displayValue}
        </option>
      ))}
    </select>
  );
};
