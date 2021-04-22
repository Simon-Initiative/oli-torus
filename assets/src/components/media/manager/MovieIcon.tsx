import * as React from 'react';

export interface MovieIconProps {
  className?: string;
}

/**
 * MovieIcon React Stateless Component
 */
export const MovieIcon: React.StatelessComponent<MovieIconProps> = ({
  // eslint-disable-next-line
  className,
  // eslint-disable-next-line
  children,
}) => {
  return (
    <div className={`example-component ${className || ''}`}>
      {children}
    </div>
  );
};
