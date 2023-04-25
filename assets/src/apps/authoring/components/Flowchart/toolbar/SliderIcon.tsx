import * as React from 'react';

export const SliderIcon: React.FC<{ stroke: string }> = ({ stroke = '#222439', ...props }) => (
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
      d="M6 9h8M16 9h2M14 11V7M18 15h-8M8 15H6M10 17v-4"
      stroke={stroke}
      strokeLinecap="round"
    />
  </svg>
);
