import * as React from 'react';

export const HubSpokeIcon: React.FC<{ stroke?: string; fill?: string }> = ({
  stroke = '#222439',
  fill = '#F3F5F8',
  ...props
}) => (
  <svg
    {...props}
    width="24"
    height="24"
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <rect width="24" height="24" rx="3" fill={fill} />
    <text x="6" y="17" fontFamily="serif" fontWeight="bold" fontSize="14" fill={fill}>
      ƒx
    </text>
  </svg>
);
