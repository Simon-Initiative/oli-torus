import React, { PropsWithChildren } from 'react';
import { classNames } from 'utils/classNames';

export type Variant =
  | 'primary'
  | 'secondary'
  | 'tertiary'
  | 'light'
  | 'dark'
  | 'info'
  | 'success'
  | 'warning'
  | 'danger';

export type Size = 'xs' | 'sm' | 'md' | 'lg' | 'xl';

const variantClasses = (variant?: Variant) => {
  switch (variant) {
    case 'primary':
      return 'text-white bg-primary-500 hover:bg-primary-600 active:bg-primary-700 focus:ring-2 focus:ring-primary-400 dark:bg-primary-600 dark:hover:bg-primary dark:active:bg-primary-400 focus:outline-none dark:focus:ring-primary-700';
    case 'secondary':
      return 'text-body-color bg-transparent hover:bg-gray-200 active:text-white active:bg-primary-600 focus:ring-2 focus:ring-primary-400 dark:text-body-color-dark dark:hover:bg-gray-600 dark:active:bg-primary-400 focus:outline-none dark:focus:ring-primary-700';
    case 'tertiary':
      return 'text-primary-700 bg-primary-50 hover:bg-primary-100 active:bg-primary-200 focus:ring-2 focus:ring-primary-100 dark:text-primary-300 dark:bg-primary-800 dark:hover:bg-primary-700 dark:active:bg-primary-600 focus:outline-none dark:focus:ring-primary-800';
    case 'light':
      return 'text-body-color bg-gray-100 hover:bg-gray-200 active:bg-gray-300 focus:ring-2 focus:ring-gray-100 dark:text-white dark:bg-gray-800 dark:hover:bg-gray-700 dark:active:bg-gray-600 focus:outline-none dark:focus:ring-gray-800';
    case 'dark':
      return 'text-white bg-gray-500 hover:bg-gray-600 active:bg-gray-700 focus:ring-2 focus:ring-gray-500 dark:text-white dark:bg-gray-500 dark:hover:bg-gray-400 dark:active:bg-gray-300 focus:outline-none dark:focus:ring-gray-500';
    case 'info':
      return 'text-white bg-gray-500 hover:bg-gray-600 active:bg-gray-700 focus:ring-2 focus:ring-gray-400 dark:bg-gray-600 dark:hover:bg-gray-500 dark:active:bg-gray-400 focus:outline-none dark:focus:ring-gray-700';
    case 'success':
      return 'text-white bg-green-500 hover:bg-green-600 active:bg-green-700 focus:ring-2 focus:ring-green-400 dark:bg-green-600 dark:hover:bg-green-500 dark:active:bg-green-400 focus:outline-none dark:focus:ring-green-700';
    case 'warning':
      return 'text-white bg-yellow-500 hover:bg-yellow-600 active:bg-yellow-700 focus:ring-2 focus:ring-yellow-400 dark:bg-yellow-600 dark:hover:bg-yellow-500 dark:active:bg-yellow-400 focus:outline-none dark:focus:ring-yellow-700';
    case 'danger':
      return 'text-white bg-red-500 hover:bg-red-600 active:bg-red-700 focus:ring-2 focus:ring-red-400 dark:bg-red-600 dark:hover:bg-red-500 dark:active:bg-red-400 focus:outline-none dark:focus:ring-red-700';
    default:
      return '';
  }
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

type ButtonProps = {
  variant?: Variant;
  size?: Size;
  className?: string;
  disabled?: boolean;
  onClick: () => void;
};

export const Button = ({
  className,
  variant,
  size,
  children,
  disabled,
  onClick,
}: PropsWithChildren<ButtonProps>) => (
  <button
    className={classNames(
      'rounded whitespace-nowrap',
      variantClasses(variant),
      sizeClasses(size),
      disabled &&
        'text-gray-500 hover:text-gray-500 focus:ring-0 hover:no-underline cursor-default',
      className,
    )}
    onClick={onClick}
    disabled={disabled}
  >
    {children}
  </button>
);
