import React, { createRef, PropsWithChildren, useEffect } from 'react';
import { classNames } from 'utils/classNames';

interface TooltipProps {
  className?: string;
  title: string;
  placement?: 'top' | 'bottom' | 'left' | 'right';
}
export const Tooltip = ({
  className,
  title,
  placement,
  children,
}: PropsWithChildren<TooltipProps>) => {
  const ref = createRef<HTMLElement>();

  useEffect(() => {
    const tooltipEl = ref.current !== null && ($(ref.current) as any);
    tooltipEl.tooltip();

    return () => {
      // make sure the tooltip is properly disposed of
      tooltipEl.tooltip('dispose');
    };
  }, [ref]);

  return (
    <span
      ref={ref}
      className={classNames(className, 'inline-flex items-center')}
      data-placement={placement ?? 'top'}
      title={title}
    >
      {children}
    </span>
  );
};
