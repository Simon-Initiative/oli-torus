import * as React from 'react';

export interface AudioIconProps {
  className?: string;
}

/**
 * AudioIcon React Stateless Component
 */
export const AudioIcon: React.StatelessComponent<AudioIconProps> = ({
  className,
  children,
}) => {
  return (
    <div className={`example-component ${className || ''}`}>
      {children}
    </div>
  );
};
