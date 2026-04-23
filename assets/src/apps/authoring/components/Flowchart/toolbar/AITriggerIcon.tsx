import * as React from 'react';

export const AITriggerIcon: React.FC<{ stroke?: string; fill?: string }> = ({
  stroke = '#222439',
  fill = '#F3F5F8',
  ...props
}) => (
  <svg
    {...props}
    width={24}
    height={24}
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    role="img"
    aria-label="AI activation point icon"
  >
    <rect width={24} height={24} rx={3} fill={fill} />
    <path
      d="M15.25 5.25L16.85 8.65L20.25 10.25L16.85 11.85L15.25 15.25L13.65 11.85L10.25 10.25L13.65 8.65L15.25 5.25Z"
      fill={stroke}
    />
    <path
      d="M8.25 13.5L9.35 16.15L12 17.25L9.35 18.35L8.25 21L7.15 18.35L4.5 17.25L7.15 16.15L8.25 13.5Z"
      fill={stroke}
    />
    <path
      d="M6 4L6.8 5.95L8.75 6.75L6.8 7.55L6 9.5L5.2 7.55L3.25 6.75L5.2 5.95L6 4Z"
      fill={stroke}
    />
  </svg>
);
