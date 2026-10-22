import React from 'react';
import { classNames } from 'utils/classNames';

interface Props {
  className?: string;
  disabled?: boolean;
  ariaHidden?: boolean;
}

const VisualIndicator = ({ className, checked }: Props & { checked: boolean }) => (
  <span
    aria-hidden="true"
    className={classNames(
      'oli-radio inline-flex h-4 w-4 flex-shrink-0 items-center justify-center rounded-full border border-current',
      checked && 'bg-current',
      className,
    )}
  >
    {checked && <span className="h-2 w-2 rounded-full bg-white" />}
  </span>
);

const Checked = ({ className, disabled, ariaHidden }: Props) =>
  ariaHidden ? (
    <VisualIndicator className={className} checked />
  ) : (
    <input
      className={classNames(className, 'oli-radio', 'flex-shrink-0')}
      type="radio"
      checked
      disabled={disabled || false}
      readOnly
      tabIndex={-1}
    />
  );

const Unchecked = ({ className, disabled, ariaHidden }: Props) =>
  ariaHidden ? (
    <VisualIndicator className={className} checked={false} />
  ) : (
    <input
      className={`oli-radio flex-shrink-0 ${className || ''}`}
      type="radio"
      disabled={disabled || false}
      readOnly
      tabIndex={-1}
    />
  );

const Correct = (props: Props) => (
  <Checked {...props} className={classNames(props.className, 'correct')} disabled />
);
const Incorrect = (props: Props) => (
  <Checked {...props} className={classNames(props.className, 'incorrect')} disabled />
);

export const Radio = {
  Checked,
  Unchecked,
  Correct,
  Incorrect,
};
