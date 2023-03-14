import React from 'react';
import { classNames } from 'utils/classNames';
import { Tooltip } from 'components/common/Tooltip';

interface InfoTipProps {
  className?: string;
  title: string;
}
export const InfoTip = ({ className, title }: InfoTipProps) => (
  <Tooltip title={title}>
    <i className={classNames('fa-solid fa-circle-info mx-2', className)}></i>
  </Tooltip>
);
