import React from 'react';

interface Props {
  onChange: React.ChangeEventHandler<HTMLInputElement>;
  value: string | number;
  disabled?: boolean;
  placeholder?: string;
}
export const VlabInput: React.FC<Props> = (props) => {
  return (
    <input
      placeholder="Vlab Value" //{props.placeholder}
      readOnly="true"
      type="number"
      aria-label="answer submission textbox"
      className="form-control"
      onChange={props.onChange}
      value={props.value}
      disabled={typeof props.disabled === 'boolean' ? props.disabled : false}
    />
  );
};
