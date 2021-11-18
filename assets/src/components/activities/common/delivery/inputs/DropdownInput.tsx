import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import React from 'react';

interface Props {
  selected: any;
  options: SelectOption[];
  onChange: React.ChangeEventHandler<HTMLSelectElement>;
  disabled?: boolean;
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
      onChange={props.onChange}
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
