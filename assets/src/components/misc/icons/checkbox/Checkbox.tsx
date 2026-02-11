import React from 'react';

interface Props {
  className?: string;
  disabled?: boolean;
}

const Checked = ({ className, disabled }: Props) => (
  <input
    className={`oli-checkbox flex-shrink-0 ${className || ''}`}
    type="checkbox"
    checked
    disabled={disabled || false}
    readOnly
    tabIndex={-1}
  />
);

const Unchecked = ({ className, disabled }: Props) => (
  <input
    className={`oli-checkbox flex-shrink-0 ${className || ''}`}
    type="checkbox"
    disabled={disabled || false}
    readOnly
    tabIndex={-1}
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
