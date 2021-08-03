import React from 'react';
import './Checkbox.scss';

interface Props {
  className?: string;
  disabled?: boolean;
}

const Checked = ({ className, disabled }: Props) => (
  <input
    className={`oli-checkbox ${className || ''}`}
    type="checkbox"
    checked
    disabled={disabled || false}
    readOnly
  />
);

const Unchecked = ({ className, disabled }: Props) => (
  <input
    className={`oli-checkbox ${className || ''}`}
    type="checkbox"
    disabled={disabled || false}
    readOnly
  />
);
const Correct = () => <Checked className="correct" disabled />;
const Incorrect = () => <Checked className="incorrect" disabled />;

export const Checkbox = {
  Checked,
  Unchecked,
  Correct,
  Incorrect,
};
