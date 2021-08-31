import React from 'react';

interface Props {
  onChange: React.ChangeEventHandler<HTMLInputElement>;
  value: string | number;
  disabled?: boolean;
}
export const NumericInput: React.FC<Props> = (props) => {
  return (
    <input
      type="number"
      aria-label="answer submission textbox"
      className="form-control"
      onChange={props.onChange}
      value={props.value}
      disabled={typeof props.disabled === 'boolean' ? props.disabled : false}
    />
  );
};
