import React from 'react';
import { Button } from './Button';

interface ErrorBannerProps {
  onDismissError?: () => void;
  className?: string;
  children: React.ReactNode;
}

export const ErrorBanner: React.FC<ErrorBannerProps> = ({
  onDismissError,
  children,
  className,
}) => (
  <div
    className={`bg-red-100 text-red-700 align-middle py-2 px-6 mb-1 text-base fixed-top flex flex-row justify-between shadow-lg ${className}`}
    role="alert"
  >
    <span>
      <i className="fa fa-circle-exclamation fa-2xl"></i>
    </span>
    <h3 className="pt-1">{children}</h3>
    {onDismissError && (
      <Button variant="secondary" onClick={onDismissError}>
        Dismiss
      </Button>
    )}
    {onDismissError || <div />}
  </div>
);

ErrorBanner.defaultProps = {
  className: '',
};
