import React from 'react';

interface Props {
  value: string;
  disabled?: boolean;
  placeholder?: string;
  onChange: (value: string) => void;
}
export const TextInput: React.FC<Props> = ({ onChange, value, disabled, placeholder }) => {
  return (
    <input
      placeholder={placeholder}
      type="text"
      aria-label="answer submission textbox"
      className="form-control"
      onChange={(e) => onChange(e.target.value)}
      value={value}
      disabled={typeof disabled === 'boolean' ? disabled : false}
    />
  );
};
