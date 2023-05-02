import * as React from 'react';

export const ScreenDuplicateIcon: React.FC<{ fill?: string; stroke?: string }> = ({
  fill = '#F3F5F8',
  stroke = '#222439',
}) => {
  return (
    <svg width={24} height={24} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width={24} height={24} rx={3} fill={fill} />
      <path
        d="M7.2 10.2h5.4a1.2 1.2 0 011.2 1.2v5.4a1.2 1.2 0 01-1.2 1.2H7.2A1.2 1.2 0 016 16.8v-5.4a1.2 1.2 0 011.2-1.2z"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M16.2 13.8h.6a1.2 1.2 0 001.2-1.2V7.2A1.2 1.2 0 0016.8 6h-5.4a1.2 1.2 0 00-1.2 1.2v.6"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
