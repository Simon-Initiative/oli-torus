import React from 'react';
import { Tooltip } from 'components/common/Tooltip';
import { classNames } from 'utils/classNames';

interface InfoTipProps {
  className?: string;
  title: string;
}
export const InfoTip = ({ className, title }: InfoTipProps) => (
  <Tooltip title={title}>
    <i className={classNames('fa-solid fa-circle-info mx-2', className)}></i>
  </Tooltip>
);
