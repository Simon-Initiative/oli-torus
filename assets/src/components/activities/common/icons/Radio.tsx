import React from 'react';
import './Radio.scss';

interface Props {
  className?: string;
  disabled?: boolean;
}

const Checked = ({ className, disabled }: Props) => (
  <input
    className={`oli-radio ${className || ''}`}
    type="radio"
    checked
    disabled={disabled || false}
    readOnly
  />
);

const Unchecked = ({ className, disabled }: Props) => (
  <input
    className={`oli-radio ${className || ''}`}
    type="radio"
    disabled={disabled || false}
    readOnly
  />
);
const Correct = () => <Checked className="correct" />;
const Incorrect = () => <Checked className="incorrect" disabled />;

export const Radio = {
  Checked,
  Unchecked,
  Correct,
  Incorrect,
};
