import React, { createRef, useEffect, useState } from 'react';
import { MultiInputSize } from 'components/activities/multi_input/schema';
import { disableScrollWheelChange } from 'components/activities/short_answer/utils';
import { classNames } from 'utils/classNames';
import { isValidNumber } from 'utils/number';

interface Props {
  value: string;
  disabled?: boolean;
  placeholder?: string;
  size?: MultiInputSize;
  onChange: (value: string) => void;
  onBlur?: () => void;
  onKeyUp: (e: React.KeyboardEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
}

export const NumericInput: React.FC<Props> = (props) => {
  const numericInputRef = createRef<HTMLInputElement>();
  const [uniqueId] = useState(Math.random().toString(36).substring(7));
  const [hasError, setHasError] = useState(false);

  useEffect(() => {
    if (props.value === '' || !isValidNumber(props.value)) {
      setHasError(true);
    } else {
      setHasError(false);
    }
  }, [props.value]);

  return (
    <input
      id={uniqueId}
      key={uniqueId}
      ref={numericInputRef}
      placeholder={props.placeholder}
      type="text"
      aria-label="answer submission textbox"
      className={classNames(
        'rounded-md border-2 disabled:bg-gray-100 disabled:text-gray-600',
        hasError ? 'input-error' : 'border-gray-300', // Use custom error class
        'focus:outline-none', // Remove default focus outline
        props.size && `input-size-${props.size}`,
      )}
      onChange={(e) => {
        const value = e.target.value;
        props.onChange(value);
      }}
      onBlur={props.onBlur}
      onKeyUp={props.onKeyUp}
      value={props.value}
      disabled={typeof props.disabled === 'boolean' ? props.disabled : false}
      onWheel={disableScrollWheelChange(numericInputRef)}
    />
  );
};
