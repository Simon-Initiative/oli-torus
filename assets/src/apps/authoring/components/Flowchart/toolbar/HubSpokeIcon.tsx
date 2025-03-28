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

    <circle cx="5.5" cy="12" r="2" stroke={stroke} strokeWidth="1" fill="none" />

    <circle cx="16" cy="5.5" r="2.2" stroke={stroke} strokeWidth="1" fill="none" />
    <line x1="7" y1="11" x2="14.1" y2="6.7" stroke={stroke} strokeWidth="1" strokeLinecap="butt" />

    <circle cx="18" cy="12" r="2.2" stroke={stroke} strokeWidth="1" fill="none" />
    <line x1="7.5" y1="12" x2="16" y2="12" stroke={stroke} strokeWidth="1" strokeLinecap="butt" />

    <circle cx="16" cy="18.5" r="2.2" stroke={stroke} strokeWidth="1" fill="none" />
    <line x1="7" y1="13" x2="14.1" y2="17.3" stroke={stroke} strokeWidth="1" strokeLinecap="butt" />
  </svg>
);
