import React, { createRef } from 'react';

interface Props {
  onChange: React.ChangeEventHandler<HTMLInputElement>;
  value: string | number;
  disabled?: boolean;
  placeholder?: string;
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
      onChange={props.onChange}
      value={props.value}
      disabled={typeof props.disabled === 'boolean' ? props.disabled : false}
      onWheel={handleScrollWheelChange}
    />
  );
};
