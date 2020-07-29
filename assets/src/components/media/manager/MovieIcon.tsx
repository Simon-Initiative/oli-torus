import * as React from 'react';

export interface MovieIconProps {
  className?: string;
}

/**
 * MovieIcon React Stateless Component
 */
export const MovieIcon: React.StatelessComponent<MovieIconProps> = ({
  className,
  children,
}) => {
  return (
    <div className={`example-component ${className || ''}`}>
      {children}
    </div>
  );
};
