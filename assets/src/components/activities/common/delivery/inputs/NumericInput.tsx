import { disableScrollWheelChange } from 'components/activities/short_answer/utils';
import React, { createRef } from 'react';

interface Props {
  value: string;
  disabled?: boolean;
  placeholder?: string;
  onChange: (value: string) => void;
  onBlur?: () => void;
  onKeyUp: (e: React.KeyboardEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
}
export const NumericInput: React.FC<Props> = (props) => {
  const numericInputRef = createRef<HTMLInputElement>();

  return (
    <input
      ref={numericInputRef}
      placeholder={props.placeholder}
      type="number"
      aria-label="answer submission textbox"
      className="border-gray-300 rounded-md disabled:bg-gray-100 disabled:text-gray-600"
      onChange={(e) => props.onChange(e.target.value)}
      onBlur={props.onBlur}
      onKeyUp={props.onKeyUp}
      value={props.value}
      disabled={typeof props.disabled === 'boolean' ? props.disabled : false}
      onWheel={disableScrollWheelChange(numericInputRef)}
    />
  );
};
