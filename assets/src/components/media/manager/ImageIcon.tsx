import * as React from 'react';

export interface ImageIconProps {
  className?: string;
  filename: string;
  extension: string;
  url: string;
}

/**
 * ImageIcon React Stateless Component
 */
export const ImageIcon: React.StatelessComponent<ImageIconProps> = ({
  // eslint-disable-next-line
  className,
  // eslint-disable-next-line
  url,
}) => {
  return (
    <div className={`image-icon ${className || ''}`}>
      <img src={url} />
    </div>
  );
};
