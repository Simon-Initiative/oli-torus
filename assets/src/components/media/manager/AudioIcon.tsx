import * as React from 'react';

export interface AudioIconProps {
  className?: string;
}

/**
 * AudioIcon React Stateless Component
 */
export const AudioIcon: React.StatelessComponent<AudioIconProps> = ({
  // eslint-disable-next-line
  className,
  // eslint-disable-next-line
  children,
}) => {
  return <div className={`example-component ${className || ''}`}>{children}</div>;
};
