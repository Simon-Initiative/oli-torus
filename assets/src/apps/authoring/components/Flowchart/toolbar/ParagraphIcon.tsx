import * as React from 'react';

export const ParagraphIcon: React.FC<{ stroke: string }> = ({ stroke = '#222439', ...props }) => {
  return (
    <svg
      width={24}
      height={24}
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <rect width={24} height={24} rx={3} fill="#F3F5F8" />
      <path
        d="M18 8H6M18 13.332H6M16 10.666H8M16 16H8"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
