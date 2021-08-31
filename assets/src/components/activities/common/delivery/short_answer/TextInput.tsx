import React from 'react';

interface Props {
  onChange: React.ChangeEventHandler<HTMLInputElement>;
  value: string | number;
  disabled?: boolean;
}
export const TextInput: React.FC<Props> = ({ onChange, value, disabled }) => {
  return (
    <input
      type="text"
      aria-label="answer submission textbox"
      className="form-control"
      onChange={onChange}
      value={value}
      disabled={typeof disabled === 'boolean' ? disabled : false}
    />
  );
};
