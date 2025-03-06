import * as React from 'react';

export const FlowchartIcon: React.FC<{ fill?: string; stroke?: string }> = ({
  fill = '#fff',
  stroke = '#222439',
}) => {
  return (
    <svg width={24} height={24} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <g
        clipPath="url(#clip0_304_15587)"
        stroke={stroke}
        strokeWidth={1.5}
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M21.25 3h-4.5a.75.75 0 00-.75.75v4.5c0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75v-4.5a.75.75 0 00-.75-.75zM7.25 9h-4.5a.75.75 0 00-.75.75v4.5c0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75v-4.5A.75.75 0 007.25 9zM21.25 14h-4.5a.75.75 0 00-.75.75v4.5c0 .414.336.75.75.75h4.5a.75.75 0 00.75-.75v-4.5a.75.75 0 00-.75-.75zM8 12h4M16 6h-2a2 2 0 00-2 2v7a2 2 0 002 2h2" />
      </g>
      <defs>
        <clipPath id="clip0_304_15587">
          <path fill={fill} d="M0 0H24V24H0z" />
        </clipPath>
      </defs>
    </svg>
  );
};
