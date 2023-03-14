import React from 'react';

interface Props {
  value: string;
  disabled?: boolean;
  placeholder?: string;
  onChange: (value: string) => void;
  onBlur?: () => void;
  onKeyUp: (e: React.KeyboardEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
}
export const TextInput: React.FC<Props> = ({
  onChange,
  value,
  disabled,
  placeholder,
  onBlur,
  onKeyUp,
}) => {
  return (
    <input
      placeholder={placeholder}
      type="text"
      aria-label="answer submission textbox"
      className="border-gray-300 rounded-md disabled:bg-gray-100 disabled:text-gray-600"
      onChange={(e) => onChange(e.target.value)}
      onBlur={onBlur}
      onKeyUp={onKeyUp}
      value={value}
      disabled={typeof disabled === 'boolean' ? disabled : false}
    />
  );
};
