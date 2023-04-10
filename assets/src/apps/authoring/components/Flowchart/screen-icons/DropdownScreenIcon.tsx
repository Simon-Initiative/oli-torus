import * as React from 'react';

export const DropdownScreenIcon: React.FC<{
  fill?: string;
  stroke?: string;
}> = ({ fill = '#87CD9B', stroke = '#222439' }) => {
  return (
    <svg width={24} height={24} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width={24} height={24} rx={3} fill={fill} />
      <path
        d="M7.5 9.75l4.5 4.5 4.5-4.5"
        stroke={stroke}
        strokeMiterlimit={10}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
