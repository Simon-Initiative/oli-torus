import React from 'react';
import { classNames } from 'utils/classNames';

interface Props {
  className?: string;
  disabled?: boolean;
  'aria-hidden'?: boolean;
}

const VisualIndicator = ({ className, disabled, checked }: Props & { checked: boolean }) => (
  <span
    aria-hidden="true"
    className={classNames(
      'oli-checkbox inline-flex h-4 w-4 flex-shrink-0 items-center justify-center rounded border border-current',
      checked && 'bg-current',
      disabled && 'opacity-50',
      className,
    )}
  >
    {checked && <span className="h-2.5 w-2.5 rounded-sm bg-white" />}
  </span>
);

const Checked = ({ className, disabled, 'aria-hidden': ariaHidden }: Props) =>
  ariaHidden ? (
    <VisualIndicator className={className} disabled={disabled} checked />
  ) : (
    <input
      className={`oli-checkbox flex-shrink-0 ${className || ''}`}
      type="checkbox"
      checked
      disabled={disabled || false}
      readOnly
      tabIndex={-1}
    />
  );

const Unchecked = ({ className, disabled, 'aria-hidden': ariaHidden }: Props) =>
  ariaHidden ? (
    <VisualIndicator className={className} disabled={disabled} checked={false} />
  ) : (
    <input
      className={`oli-checkbox flex-shrink-0 ${className || ''}`}
      type="checkbox"
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

export const Checkbox = {
  Checked,
  Unchecked,
  Correct,
  Incorrect,
};
