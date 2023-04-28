import * as React from 'react';

export const MultilineTextScreenIcon: React.FC<{
  fill?: string;
  stroke?: string;
}> = ({ fill = '#87CD9B', stroke = '#222439' }) => {
  return (
    <svg width={24} height={24} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width={24} height={24} rx={3} fill={fill} />
      <path
        d="M18 8H6M18 13.333H6M16 10.667H8M16 16H8"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
