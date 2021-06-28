import React from 'react';
import './Radio.scss';

interface Props {
  className?: string;
}

const Checked = ({ className }: Props) => (
  <input className={`oli-radio ${className}`} type="radio" checked readOnly />
);

const Unchecked = ({ className }: Props) => (
  <input className={`oli-radio ${className}`} type="radio" readOnly />
);
const Correct = () => <Checked className="correct" />;
const Incorrect = () => <Checked className="incorrect" />;

export const Radio = {
  Checked,
  Unchecked,
  Correct,
  Incorrect,
};
