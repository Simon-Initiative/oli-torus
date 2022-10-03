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
}

export interface LoadingSpinnerState {}
export class LoadingSpinner extends React.PureComponent<LoadingSpinnerProps, LoadingSpinnerState> {
  constructor(props: LoadingSpinnerProps) {
    super(props);
  }

  render() {
    const { className, failed, children, size } = this.props;

    const sizeClass =
      size === LoadingSpinnerSize.Small
        ? 'ls-small'
        : size === LoadingSpinnerSize.Large
        ? 'ls-large'
        : 'ls-medium';

    return (
      <div className={classNames(styles.loadingSpinner, sizeClass, className)}>
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
