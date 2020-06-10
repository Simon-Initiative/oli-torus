import * as React from 'react';
import "./LoadingSpinner.scss";

export enum LoadingSpinnerSize {
  Small,
  Normal,
  Large,
}

export interface LoadingSpinnerProps {
  className?: string;
  failed?: boolean;
  message?: string;
  size?: LoadingSpinnerSize;
}

export interface LoadingSpinnerState {

}

/**
 * LoadingSpinner React Component
 */
export class LoadingSpinner
  extends React.PureComponent<LoadingSpinnerProps, LoadingSpinnerState> {

  constructor(props: LoadingSpinnerProps) {
    super(props);
  }

  render() {
    const { message, failed, children, size } = this.props;

    const sizeClass = size === LoadingSpinnerSize.Small
      ? 'ls-small'
      : size === LoadingSpinnerSize.Large
      ? 'ls-large'
      : 'ls-normal';

    return (
      <div className={'LoadingSpinner ' + sizeClass}>
        {failed
          ? <i className="fa fa-times-circle" />
          : <i className="fas fa-circle-notch fa-spin fa-1x fa-fw" />}
        &nbsp;{message ? message : children}
      </div>
    );
  }
}
