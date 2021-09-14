import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import React from 'react';

interface Props {
  options: SelectOption[];
  onChange: React.ChangeEventHandler<HTMLSelectElement>;
  disabled?: boolean;
}
export const DropdownInput: React.FC<Props> = (props) => {
  return (
    <select
      onChange={props.onChange}
      disabled={typeof props.disabled === 'boolean' ? props.disabled : false}
      className="custom-select"
      style={{ flexBasis: '160px', width: '160px' }}
    >
      {props.options.map((option, i) => (
        <option key={i} value={option.value}>
          {option.displayValue}
        </option>
      ))}
    </select>
  );
};
