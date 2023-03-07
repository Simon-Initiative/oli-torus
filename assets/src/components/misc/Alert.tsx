import React from 'react';

interface AlertProps {
  className?: string;
  children: React.ReactNode;
  variant?: 'info' | 'success' | 'warning' | 'error';
}

// TODO: Are there more torus aligned colors we can use here?
const variants = {
  info: 'bg-blue-100 text-blue-700',
  success: 'bg-green-100 text-green-700',
  warning: 'bg-yellow-100 text-yellow-700',
  error: 'bg-red-100 text-red-700',
};

export const Alert: React.FC<AlertProps> = ({ children, className, variant }) => (
  // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
  <div className={` rounded-lg py-5 px-6  text-base  mb-3 ${variants[variant!]} ${className}`}>
    {children}
  </div>
);

Alert.defaultProps = {
  variant: 'info',
  className: '',
};
