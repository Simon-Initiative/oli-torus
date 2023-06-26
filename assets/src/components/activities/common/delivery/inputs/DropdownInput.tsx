import React from 'react';
import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { MultiInputSize } from 'components/activities/multi_input/schema';
import { classNames } from 'utils/classNames';

interface Props {
  selected: any;
  options: SelectOption[];
  disabled?: boolean;
  size?: MultiInputSize;
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
      className={classNames(
        'custom-select dropdown-input',
        props.size && `input-size-${props.size}`,
      )} // see: multi-input.scss
    >
      {options.map((option, i) => (
        <option selected={option.value === props.selected} key={i} value={option.value}>
          {option.displayValue}
        </option>
      ))}
    </select>
  );
};
