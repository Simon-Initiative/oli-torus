import React, { ChangeEvent } from 'react';

const questionTypes: { value: string; displayValue: string }[] = [
  { value: 'mc', displayValue: 'Multiple Choice' },
  { value: 'sa', displayValue: 'Short Answer' },
];

type OptionsProps = {
  editMode: boolean;
};
export const QuestionTypeDropdown = ({}: OptionsProps) => {
  const onChange = (v: ChangeEvent<HTMLSelectElement>) => null;

  return (
    <div>
      <label htmlFor="question-type">Question Type</label>
      <select
        style={{ width: '200px' }}
        disabled
        className="form-control"
        value="mc"
        onChange={onChange}
        name="question-type"
        id="question-type"
      >
        {questionTypes.map((option) => (
          <option key={option.value} value={option.value}>
            {option.displayValue}
          </option>
        ))}
      </select>
    </div>
  );
};
