import React from 'react';
import { MultiInputSize } from 'components/activities/multi_input/schema';
import { classNames } from 'utils/classNames';

interface Props {
  value: string;
  disabled?: boolean;
  placeholder?: string;
  size?: MultiInputSize;
  onChange: (value: string) => void;
  onBlur?: () => void;
  onKeyUp: (e: React.KeyboardEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
}
export const TextInput: React.FC<Props> = ({
  onChange,
  value,
  disabled,
  placeholder,
  size,
  onBlur,
  onKeyUp,
}) => {
  return (
    <input
      placeholder={placeholder}
      type="text"
      aria-label="answer submission textbox"
      className={classNames(
        'border-gray-300 rounded-md disabled:bg-gray-100 disabled:text-gray-600',
        size && `input-size-${size}`,
      )}
      onChange={(e) => onChange(e.target.value)}
      onBlur={onBlur}
      onKeyUp={onKeyUp}
      value={value}
      disabled={typeof disabled === 'boolean' ? disabled : false}
    />
  );
};
