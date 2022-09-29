import React from 'react';

interface Props {
  value: string;
  rows?: number;
  cols?: number;
  disabled?: boolean;
  onChange: (value: string) => void;
  onBlur?: () => void;
}
export const TextareaInput: React.FC<Props> = (props) => {
  return (
    <textarea
      aria-label="answer submission textbox"
      rows={typeof props.rows === 'number' ? props.rows : 5}
      cols={typeof props.rows === 'number' ? props.cols : 80}
      className="form-control"
      onChange={(e) => props.onChange(e.target.value)}
      onBlur={props.onBlur}
      value={props.value}
      disabled={typeof props.disabled === 'boolean' ? props.disabled : false}
    ></textarea>
  );
};
