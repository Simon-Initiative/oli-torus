import React from 'react';
import './Checkbox.scss';

interface Props {
  className?: string;
}

const Checked = ({ className }: Props) => (
  <input className={`oli-checkbox ${className}`} type="checkbox" checked readOnly />
);

const Unchecked = ({ className }: Props) => (
  <input className={`oli-checkbox ${className}`} type="checkbox" readOnly />
);
const Correct = () => <Checked className="correct" />;
const Incorrect = () => <Checked className="incorrect" />;

export const Checkbox = {
  Checked,
  Unchecked,
  Correct,
  Incorrect,
};
