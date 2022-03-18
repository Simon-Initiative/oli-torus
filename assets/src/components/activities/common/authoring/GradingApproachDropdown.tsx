import React from 'react';
import { GradingApproach } from 'components/activities/types';
export type SelectOption<K = string> = { value: K; displayValue: string };

const options = [
  { value: GradingApproach.automatic, displayValue: 'Automatic' },
  { value: GradingApproach.manual, displayValue: 'Instructor manual grading' },
];

type GradingApproachDropdownProps<K> = {
  editMode: boolean;
  onChange: (inputType: K) => void;
  selected: K;
};
export const GradingApproachDropdown = <K extends string>({
  onChange,
  editMode,
  selected,
}: GradingApproachDropdownProps<K>) => {
  const handleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    if (!options.find(({ value }) => value === e.target.value)) {
      return;
    }
    onChange(e.target.value as any);
  };

  return (
    <div className="mb-4 d-flex">
      <span>Grading Approach:</span>
      <select
        style={{ width: 250 }}
        disabled={!editMode}
        className="form-control ml-1"
        value={selected}
        onChange={handleChange}
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.displayValue}
          </option>
        ))}
      </select>
    </div>
  );
};
