import { disableScrollWheelChange } from 'components/activities/short_answer/utils';
import React, { createRef } from 'react';

interface Props {
  value: string;
  disabled?: boolean;
  placeholder?: string;
  onChange: (value: string) => void;
  onBlur?: () => void;
}
export const NumericInput: React.FC<Props> = (props) => {
  const numericInputRef = createRef<HTMLInputElement>();

  return (
    <input
      ref={numericInputRef}
      placeholder={props.placeholder}
      type="number"
      aria-label="answer submission textbox"
      className="form-control"
      onChange={(e) => props.onChange(e.target.value)}
      onBlur={props.onBlur}
      value={props.value}
      disabled={typeof props.disabled === 'boolean' ? props.disabled : false}
      onWheel={disableScrollWheelChange(numericInputRef)}
    />
  );
};
