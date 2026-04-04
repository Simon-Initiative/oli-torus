import * as React from 'react';

export const AITriggerIcon: React.FC<{ stroke?: string; fill?: string }> = ({
  stroke = '#0165DA',
  fill = '#E8F3FF',
  ...props
}) => (
  <svg
    width={24}
    height={24}
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    {...props}
  >
    <rect width={24} height={24} rx={3} fill={fill} />
    <path
      d="M15.5 5.5L16.7 8.3L19.5 9.5L16.7 10.7L15.5 13.5L14.3 10.7L11.5 9.5L14.3 8.3L15.5 5.5Z"
      fill={stroke}
    />
    <path
      d="M8.5 11L9.3 12.9L11.2 13.7L9.3 14.5L8.5 16.4L7.7 14.5L5.8 13.7L7.7 12.9L8.5 11Z"
      fill={stroke}
    />
    <path
      d="M6.5 5.5L7 6.7L8.2 7.2L7 7.7L6.5 8.9L6 7.7L4.8 7.2L6 6.7L6.5 5.5Z"
      fill={stroke}
    />
  </svg>
);
