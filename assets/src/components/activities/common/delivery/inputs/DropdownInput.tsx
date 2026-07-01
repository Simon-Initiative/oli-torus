import React from 'react';
import { SelectOption } from 'components/activities/common/authoring/InputTypeDropdown';
import { MultiInputSize } from 'components/activities/multi_input/schema';
import { classNames } from 'utils/classNames';

interface Props {
  value?: string;
  options: SelectOption[];
  disabled?: boolean;
  size?: MultiInputSize;
  className?: string;
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
      value={props.value || ''}
      className={classNames(
        'custom-select dropdown-input',
        props.size && `input-size-${props.size}`,
        props.className,
      )} // see: multi-input.scss
      aria-label="Select answer"
    >
      {options.map((option, i) => (
        <option
          key={i}
          value={option.value}
          // prevent selection of initial blank choice prepended above
          disabled={i === 0 ? true : false}
        >
          {option.displayValue}
        </option>
      ))}
    </select>
  );
};
