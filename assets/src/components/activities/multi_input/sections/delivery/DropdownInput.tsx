import React from 'react';

interface Props {
  options: { value: string | number; content: string; selected?: boolean }[];
  onChange: React.ChangeEventHandler<HTMLSelectElement>;
  disabled?: boolean;
}
export const DropdownInput: React.FC<Props> = (props) => {
  console.log('options', props.options);
  return (
    <select
      onChange={props.onChange}
      disabled={typeof props.disabled === 'boolean' ? props.disabled : false}
      className="custom-select"
      style={{ color: 'black', fontWeight: 500, flexBasis: '160px', width: '160px' }}
    >
      {props.options.map((option, i) => (
        <option
          selected={typeof option.selected === 'boolean' ? option.selected : false}
          key={i}
          value={option.value}
        >
          {option.content}
        </option>
      ))}
    </select>
  );
};
