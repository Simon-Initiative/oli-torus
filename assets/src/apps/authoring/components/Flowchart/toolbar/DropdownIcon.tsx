import * as React from 'react';

export const DropdownIcon: React.FC<{ stroke: string }> = ({ stroke = '#222439', ...props }) => (
  <svg
    width={24}
    height={24}
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    {...props}
  >
    <rect width={24} height={24} rx={3} fill="#F3F5F8" />
    <path d="M13 11l2 2 2-2" stroke={stroke} strokeLinecap="round" strokeLinejoin="round" />
    <rect
      x={4}
      y={7}
      width={16}
      height={10}
      rx={2}
      stroke={stroke}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);
