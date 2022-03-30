import React, { PropsWithChildren, ReactNode } from 'react';
import { classNames, ClassName } from 'utils/classNames';

interface DropdownSelectProps {
  className?: ClassName;
  bsBtnClass?: string;
  text: ReactNode;
}

export const DropdownSelect = ({
  text,
  bsBtnClass,
  className,
  children,
}: PropsWithChildren<DropdownSelectProps>) => {
  return (
    <div className={classNames('dropdown', className)}>
      <button
        className={classNames('btn', bsBtnClass || 'btn-primary', 'dropdown-toggle')}
        type="button"
        id="dropdownMenuButton"
        data-toggle="dropdown"
        aria-expanded="false"
      >
        {text}
      </button>
      <div className="dropdown-menu" aria-labelledby="dropdownMenuButton">
        {children}
      </div>
    </div>
  );
};

interface DropdownItemProps {
  className?: ClassName;
  onClick?: React.MouseEventHandler<HTMLDivElement>;
}
export const DropdownItem = ({
  className,
  children,
  onClick,
}: PropsWithChildren<DropdownItemProps>) => {
  return (
    <div className={classNames('dropdown-item', 'cursor-pointer', className)} onClick={onClick}>
      {children}
    </div>
  );
};
