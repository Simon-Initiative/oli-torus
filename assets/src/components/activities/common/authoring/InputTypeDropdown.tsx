import React from 'react';

export type SelectOption<K = string> = { value: K; displayValue: string };

type InputTypeDropdownProps<K> = {
  editMode: boolean;
  onChange: (inputType: K) => void;
  options: SelectOption<K>[];
  selected: K;
};
export const InputTypeDropdown = <K extends string>({
  onChange,
  editMode,
  selected,
  options,
}: InputTypeDropdownProps<K>) => {
  const handleChange = (e: React.ChangeEvent<HTMLSelectElement>) => {
    if (!options.find(({ value }) => value === e.target.value)) {
      return;
    }
    onChange(e.target.value as any);
  };

  return (
    <select
      style={{ width: 150 }}
      disabled={!editMode}
      className="form-control ml-1"
      value={selected}
      onChange={handleChange}
      name="question-type"
      id="question-type"
    >
      {options.map((option) => (
        <option key={option.value} value={option.value}>
          {option.displayValue}
        </option>
      ))}
    </select>
  );
};
