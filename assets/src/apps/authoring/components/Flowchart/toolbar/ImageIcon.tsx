import * as React from 'react';

export const ImageIcon: React.FC<{ stroke: string }> = ({ stroke = '#222439', ...props }) => {
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
        d="M16.667 6H7.333C6.597 6 6 6.597 6 7.333v9.334C6 17.403 6.597 18 7.333 18h9.334c.736 0 1.333-.597 1.333-1.333V7.333C18 6.597 17.403 6 16.667 6z"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M9.331 10.665a1.333 1.333 0 100-2.667 1.333 1.333 0 000 2.667z" fill={stroke} />
      <path
        d="M17.999 14.001l-3.334-3.333-7.333 7.333"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
