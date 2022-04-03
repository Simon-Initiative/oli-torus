import React, { PropsWithChildren } from 'react';
import { classNames, ClassName } from 'utils/classNames';

import './ThreeStateToggle.scss';

interface ThreeStateToggleProps {
  className?: ClassName;
}

export const ThreeStateToggle = ({
  className,
  children,
}: PropsWithChildren<ThreeStateToggleProps>) => {
  return (
    <div className={classNames('three-state-toggle', className)}>
      <div className="switch-toggle switch-3 switch-candy">{children}</div>
    </div>
  );
};

interface ToggleOptionProps {
  id: string;
  checked?: boolean;
  onClick?: React.MouseEventHandler<HTMLDivElement>;
}
export const ToggleOption = ({
  id,
  checked,
  children,
  onClick,
}: PropsWithChildren<ToggleOptionProps>) => {
  return (
    <>
      <input type="radio" id={id} name="state" onClick={onClick} checked={checked} />
      <label htmlFor={id}>{children}</label>
    </>
  );
};
