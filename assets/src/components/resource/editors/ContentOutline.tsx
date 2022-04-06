import React, { PropsWithChildren } from 'react';
import { classNames, ClassName } from 'utils/classNames';

import styles from './ContentOutline.scss';

interface ContentOutlineProps {
  className?: ClassName;
}

export const ContentOutline = ({ className, children }: PropsWithChildren<ContentOutlineProps>) => {
  return <div className={classNames(styles.contentOutline, className)}></div>;
};
