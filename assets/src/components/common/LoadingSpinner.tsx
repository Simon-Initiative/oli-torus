import * as React from 'react';
import { classNames } from 'utils/classNames';
import styles from './LoadingSpinner.modules.scss';

export enum LoadingSpinnerSize {
  Small,
  Medium,
  Large,
}

export interface LoadingSpinnerProps {
  className?: string;
  failed?: boolean;
  size?: LoadingSpinnerSize;
  align?: 'left' | 'center' | 'right';
}

export interface LoadingSpinnerState {}
export class LoadingSpinner extends React.PureComponent<LoadingSpinnerProps, LoadingSpinnerState> {
  constructor(props: LoadingSpinnerProps) {
    super(props);
  }

  render() {
    const { className, failed, children, size, align } = this.props;

    const sizeClass =
      size === LoadingSpinnerSize.Small
        ? styles.lsSmall
        : size === LoadingSpinnerSize.Large
        ? styles.lsLarge
        : styles.lsMedium;

    const alignClass =
      align === 'left'
        ? styles.alignLeft
        : align === 'right'
        ? styles.alignRight
        : styles.alignCenter;

    return (
      <div className={classNames(styles.loadingSpinner, sizeClass, alignClass, className)}>
        {failed ? (
          <i className="fa fa-times-circle text-danger" />
        ) : (
          <i className="fas fa-circle-notch fa-spin fa-1x fa-fw" />
        )}
        <span className="ml-1">{children}</span>
      </div>
    );
  }
}
