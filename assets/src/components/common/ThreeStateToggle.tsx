import React, { PropsWithChildren } from 'react';
import { ClassName, classNames } from 'utils/classNames';

interface ThreeStateToggleProps {
  className?: ClassName;
}

export const ThreeStateToggle = ({
  className,
  children,
}: PropsWithChildren<ThreeStateToggleProps>) => {
  return <div className={classNames('flex flex-row whitespace-nowrap', className)}>{children}</div>;
};

interface ToggleOptionProps {
  id: string;
  checked?: boolean;
  onChange?: () => void;
}
export const ToggleOption = ({
  id,
  checked,
  children,
  onChange,
}: PropsWithChildren<ToggleOptionProps>) => {
  return (
    <>
      <input
        type="radio"
        id={id}
        className="hidden"
        name="state"
        onChange={onChange}
        checked={checked}
      />
      <label
        htmlFor={id}
        className={classNames(
          checked && '!bg-gray-600 !text-white',
          'px-3 py-2 border-t border-b border-l last:border-r border-gray-500 text-gray-500 cursor-pointer first-of-type:rounded-l last-of-type:rounded-r hover:bg-gray-200 dark:hover:bg-gray-700',
        )}
      >
        {children}
      </label>
    </>
  );
};
