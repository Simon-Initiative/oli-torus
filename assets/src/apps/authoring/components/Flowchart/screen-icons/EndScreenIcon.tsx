import * as React from 'react';

export const EndScreenIcon: React.FC<{
  fill?: string;
  stroke?: string;
}> = ({ fill = '#87CD9B', stroke = '#222439' }) => {
  return (
    <svg width={24} height={24} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width={24} height={24} rx={3} fill={fill} />
      <path
        d="M9.75 17.25h-2.5c-.332 0-.65-.123-.884-.342A1.129 1.129 0 016 16.083V7.917c0-.31.132-.606.366-.825.235-.22.552-.342.884-.342h2.5M17.25 12h-7.5M15.297 9.75l2.25 2.25-2.25 2.25"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
