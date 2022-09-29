import React, { createRef } from 'react';

interface Props {
  value: string;
  disabled?: boolean;
  placeholder?: string;
  onChange: (value: string) => void;
  onBlur?: () => void;
}
export const NumericInput: React.FC<Props> = (props) => {
  const input = createRef<HTMLInputElement>();

  // disable changing of the value via scroll wheel in certain browsers
  const handleScrollWheelChange = () => input.current?.blur();

  return (
    <input
      ref={input}
      placeholder={props.placeholder}
      type="number"
      aria-label="answer submission textbox"
      className="form-control"
      onChange={(e) => props.onChange(e.target.value)}
      onBlur={props.onBlur}
      value={props.value}
      disabled={typeof props.disabled === 'boolean' ? props.disabled : false}
      onWheel={handleScrollWheelChange}
    />
  );
};
