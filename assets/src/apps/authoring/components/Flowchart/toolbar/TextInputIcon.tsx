import * as React from 'react';

export const TextInputIcon: React.FC<{ stroke: string }> = ({ stroke = '#222439', ...props }) => (
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
      d="M7.5 9.75V7.5h9v2.25M10.5 16.5h3M12 7.5v9"
      stroke={stroke}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);
