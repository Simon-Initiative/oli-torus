import * as React from 'react';

export const ScreenEditIcon: React.FC<{ fill?: string; stroke?: string }> = ({
  fill = '#F3F5F8',
  stroke = '#222439',
}) => {
  return (
    <svg width={24} height={24} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width={24} height={24} rx={3} fill={fill} />
      <path
        d="M12 17h6M14.673 6.4a1.363 1.363 0 111.928 1.927l-8.031 8.03L6 17l.642-2.57 8.031-8.03z"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
