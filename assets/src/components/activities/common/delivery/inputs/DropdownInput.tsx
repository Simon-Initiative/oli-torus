import React from 'react';
import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';

interface Props {
  selected: any;
  options: SelectOption[];
  disabled?: boolean;
  onChange: (value: string) => void;
}
export const DropdownInput: React.FC<Props> = (props) => {
  const options = [
    {
      value: '',
      displayValue: '',
    },
    ...props.options,
  ];

  return (
    <select
      onChange={(e) => props.onChange(e.target.value)}
      disabled={typeof props.disabled === 'boolean' ? props.disabled : false}
      className="custom-select"
      style={{ flexBasis: '160px', width: '160px' }}
    >
      {options.map((option, i) => (
        <option selected={option.value === props.selected} key={i} value={option.value}>
          {option.displayValue}
        </option>
      ))}
    </select>
  );
};
