import * as React from 'react';

export const AudioIcon: React.FC<{ stroke: string }> = ({ stroke = '#222439', ...props }) => {
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
        d="M9 16V7.333L17 6v8.667"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M7 18a2 2 0 100-4 2 2 0 000 4zM15 16.666a2 2 0 100-4 2 2 0 000 4z"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
