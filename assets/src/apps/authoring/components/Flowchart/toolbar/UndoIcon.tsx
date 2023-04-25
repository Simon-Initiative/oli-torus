import * as React from 'react';

export const UndoIcon: React.FC<{ stroke: string }> = ({ stroke = '#222439' }) => {
  return (
    <svg width={24} height={24} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <g
        clipPath="url(#clip0_497_35503)"
        stroke={stroke}
        strokeWidth={1.5}
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M4.001 13.666a8.334 8.334 0 108.334-8.334h-2.037" />
        <path d="M12.829 8.79L9.434 5.396 12.829 2" />
      </g>
      <defs>
        <clipPath id="clip0_497_35503">
          <path fill="#fff" d="M0 0H24V24H0z" />
        </clipPath>
      </defs>
    </svg>
  );
};
