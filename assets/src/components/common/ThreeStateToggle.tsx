import React, { PropsWithChildren } from 'react';
import { ClassName, classNames } from 'utils/classNames';

interface ThreeStateToggleProps {
  className?: ClassName;
}

export const ThreeStateToggle = ({
  className,
  children,
}: PropsWithChildren<ThreeStateToggleProps>) => {
  return (
    <div className={classNames('flex flex-row gap-2.5 whitespace-nowrap', className)}>
      {children}
    </div>
  );
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
          checked && 'dark:!bg-slate-800 dark:!border-zinc-400 !border-black/90 bg-gray-400',
          'w-7 h-7 p-1 rounded-md border dark:border-zinc-600 border-black/70 justify-center items-center gap-2.5 inline-flex cursor-pointer',
        )}
      >
        {children}
      </label>
    </>
  );
};
