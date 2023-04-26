import * as React from 'react';

export const RedoIcon: React.FC<{ stroke?: string }> = ({ stroke = '#222439' }) => {
  return (
    <svg width={24} height={24} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <g
        clipPath="url(#clip0_497_35520)"
        stroke={stroke}
        strokeWidth={1.5}
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M20.667 13.666a8.334 8.334 0 11-8.334-8.334h2.037" />
        <path d="M11.84 8.79l3.394-3.395L11.84 2" />
      </g>
      <defs>
        <clipPath id="clip0_497_35520">
          <path fill="#fff" d="M0 0H24V24H0z" />
        </clipPath>
      </defs>
    </svg>
  );
};
