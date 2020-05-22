import * as React from 'react';

import './ImageIcon.scss';

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
  className,
  url,
}) => {
  return (
    <div className={`image-icon ${className || ''}`}>
      <img src={url} />
    </div>
  );
};
