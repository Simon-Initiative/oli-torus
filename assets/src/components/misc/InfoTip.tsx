import React from 'react';
import { classNames } from 'utils/classNames';
import { Tooltip } from 'components/common/Tooltip';

interface InfoTipProps {
  className?: string;
  title: string;
}
export const InfoTip = ({ className, title }: InfoTipProps) => (
  <Tooltip title={title}>
    <i className={classNames('mx-2 material-icons-outlined', className)}>info</i>
  </Tooltip>
);
