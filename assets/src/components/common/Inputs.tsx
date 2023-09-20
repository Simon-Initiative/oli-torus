import React, { PropsWithChildren, useEffect, useRef } from 'react';
import { classNames } from 'utils/classNames';

export type Size = 'xs' | 'sm' | 'md' | 'lg' | 'xl';

type TextInputProps = {
  className?: string;
  size?: Size;
  value?: string;
  disabled?: boolean;
  autoSelect?: boolean;
  onFocus?: () => void;
  onKeyUp?: (e: any) => void;
  onChange?: (e: any) => void;
};

const sizeClasses = (size?: Size) => {
  switch (size) {
    case 'xs':
      return 'text-xs px-2 py-1';
    case 'sm':
      return 'text-sm px-2.5 py-1.5';
    case 'md':
      return 'text-base px-3 py-2';
    case 'lg':
      return 'text-lg px-4 py-2';
    case 'xl':
      return 'text-xl px-4 py-2';
    default:
      return '';
  }
};

export const TextInput = ({
  className,
  size,
  value,
  disabled,
  autoSelect,
  onFocus,
  onKeyUp,
  onChange,
}: PropsWithChildren<TextInputProps>) => {
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (autoSelect) {
      // focus and select the value of the input
      inputRef.current?.focus();
      inputRef.current?.select();
    }
  }, [inputRef, autoSelect]);

  return (
    <input
      ref={inputRef}
      className={classNames(
        'rounded border border-gray-300 focus:ring-2 focus:ring-primary focus:outline-none',
        disabled && 'bg-gray-200 text-gray-400 dark:bg-gray-800 dark:text-gray-500',
        sizeClasses(size),
        className,
      )}
      value={value}
      onFocus={onFocus}
      onKeyUp={onKeyUp}
      onChange={onChange}
    />
  );
};
