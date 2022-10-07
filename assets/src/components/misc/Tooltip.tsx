import React from 'react';
import { classNames } from 'utils/classNames';

interface Props {
  className?: string;
  title: string;
}
export const Tooltip = ({ className, title }: Props) => {
  return (
    <i
      className={classNames('ml-2 material-icons-outlined', className)}
      data-toggle="tooltip"
      data-placement="top"
      title={title}
    >
      info
    </i>
  );
};
