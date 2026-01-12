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
  label: string;
  checked?: boolean;
  onChange?: () => void;
}
export const ToggleOption = ({
  id,
  label,
  checked,
  children,
  onChange,
}: PropsWithChildren<ToggleOptionProps>) => {
  return (
    <span className="inline-flex">
      <input
        type="radio"
        id={id}
        className="sr-only peer"
        name="state"
        onChange={onChange}
        checked={checked}
      />
      <label
        htmlFor={id}
        className={classNames(
          checked && 'dark:!bg-slate-800 dark:!border-zinc-400 !border-black/90 bg-gray-400',
          'w-7 h-7 p-1 rounded-md border dark:border-zinc-600 border-black/70 justify-center items-center gap-2.5 inline-flex cursor-pointer',
          'peer-focus-visible:outline peer-focus-visible:outline-2 peer-focus-visible:outline-offset-2 peer-focus-visible:outline-black/80 dark:peer-focus-visible:outline-white',
        )}
      >
        <span className="sr-only">{label}</span>
        {children}
      </label>
    </span>
  );
};
