import * as React from 'react';

export const CheckboxIcon: React.FC<{ stroke: string }> = ({ stroke = '#222439', ...props }) => {
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
        d="M14.76 10.031l-3.684 3.75-1.674-1.704"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <rect
        x={5}
        y={5}
        width={14}
        height={14}
        rx={2.33333}
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
