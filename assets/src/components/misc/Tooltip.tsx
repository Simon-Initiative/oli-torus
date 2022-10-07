import React, { createRef, useEffect } from 'react';
import { classNames } from 'utils/classNames';

interface Props {
  className?: string;
  title: string;
}
export const Tooltip = ({ className, title }: Props) => {
  const ref = createRef<HTMLElement>();

  useEffect(() => ref.current !== null && ($(ref.current) as any).tooltip(), [ref]);

  return (
    <i
      ref={ref}
      className={classNames('ml-2 material-icons-outlined', className)}
      data-placement="top"
      title={title}
    >
      info
    </i>
  );
};
