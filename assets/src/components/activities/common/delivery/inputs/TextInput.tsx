import React from 'react';

interface Props {
  onChange: React.ChangeEventHandler<HTMLInputElement>;
  value: string;
  disabled?: boolean;
  placeholder?: string;
}
export const TextInput: React.FC<Props> = ({ onChange, value, disabled, placeholder }) => {
  return (
    <input
      placeholder={placeholder}
      type="text"
      aria-label="answer submission textbox"
      className="form-control"
      onChange={onChange}
      value={value}
      disabled={typeof disabled === 'boolean' ? disabled : false}
    />
  );
};
