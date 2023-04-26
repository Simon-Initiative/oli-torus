import * as React from 'react';

export const MultilineIcon: React.FC<{ stroke?: string; fill?: string }> = ({
  stroke = '#222439',
  fill = '#F3F5F8',
  ...props
}) => {
  return (
    <svg
      width={24}
      height={24}
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <rect width={24} height={24} rx={3} fill={fill} />
      <path d="M6 7h12M6 11.5h12M6 16h6" stroke={stroke} strokeLinecap="round" />
      <path d="M19 16h-4M17 14v4" stroke={stroke} strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
};
