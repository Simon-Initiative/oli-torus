import React from 'react';
import { classNames } from 'utils/classNames';

interface Props {
  className?: string;
  disabled?: boolean;
  ariaHidden?: boolean;
}

const Checked = ({ className, disabled, ariaHidden }: Props) => (
  <input
    aria-hidden={ariaHidden}
    className={classNames(className, 'oli-radio', 'flex-shrink-0')}
    type="radio"
    checked
    disabled={disabled || false}
    readOnly
    tabIndex={-1}
  />
);

const Unchecked = ({ className, disabled, ariaHidden }: Props) => (
  <input
    aria-hidden={ariaHidden}
    className={`oli-radio flex-shrink-0 ${className || ''}`}
    type="radio"
    disabled={disabled || false}
    readOnly
    tabIndex={-1}
  />
);
const Correct = () => <Checked className="correct" disabled />;
const Incorrect = () => <Checked className="incorrect" disabled />;

export const Radio = {
  Checked,
  Unchecked,
  Correct,
  Incorrect,
};
