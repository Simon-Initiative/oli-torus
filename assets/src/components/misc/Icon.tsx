import React from 'react';

interface IconProps extends React.ButtonHTMLAttributes<HTMLSpanElement> {
  icon: string;
  iconStyle?: string;
  className?: string;
}

export const Icon: React.FC<IconProps> = React.memo(({ icon, iconStyle, className, ...props }) => (
  <span {...props}>
    <i className={`${iconStyle} fa-${icon} ${className} `}></i>
  </span>
));

Icon.defaultProps = {
  iconStyle: 'fa-solid',
};

Icon.displayName = 'Icon';
