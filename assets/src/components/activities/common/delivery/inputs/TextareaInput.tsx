import React from 'react';

interface Props {
  onChange: React.ChangeEventHandler<HTMLTextAreaElement>;
  value: string;
  rows?: number;
  cols?: number;
  disabled?: boolean;
}
export const TextareaInput: React.FC<Props> = (props) => {
  return (
    <textarea
      aria-label="answer submission textbox"
      rows={typeof props.rows === 'number' ? props.rows : 5}
      cols={typeof props.rows === 'number' ? props.cols : 80}
      className="form-control"
      onChange={props.onChange}
      value={props.value}
      disabled={typeof props.disabled === 'boolean' ? props.disabled : false}
    ></textarea>
  );
};
