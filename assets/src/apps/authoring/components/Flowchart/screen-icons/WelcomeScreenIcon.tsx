import * as React from 'react';

export const WelcomeScreenIcon: React.FC<{
  fill?: string;
  stroke?: string;
}> = ({ fill = '#87CD9B', stroke = '#222439' }) => {
  return (
    <svg width={24} height={24} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width={24} height={24} rx={3} fill={fill} />
      <path
        d="M14.25 6.75h2.5c.331 0 .65.123.884.342.234.219.366.515.366.825v8.166c0 .31-.132.607-.366.825a1.297 1.297 0 01-.884.342h-2.5M13.5 12H6M11.547 9.75l2.25 2.25-2.25 2.25"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
