import * as React from 'react';

export const NumberInputScreenIcon: React.FC<{
  fill?: string;
  stroke?: string;
}> = ({ fill = '#87CD9B', stroke = '#222439' }) => {
  return (
    <svg width={24} height={24} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width={24} height={24} rx={3} fill={fill} />
      <path
        d="M10.5 9H6.75M10.5 15H6.75M8.625 13.125v3.75M17.25 13.875H13.5M17.25 16.125H13.5M16.5 7.5l-3 3M16.5 10.5l-3-3"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
