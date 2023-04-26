import * as React from 'react';

export const CarouselIcon: React.FC<{ stroke?: string; fill?: string }> = ({
  stroke = '#222439',
  fill = '#F3F5F8',
  ...props
}) => {
  return (
    <svg
      width={24}
      height={24}
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <rect width={24} height={24} rx={3} fill={fill} />
      <rect
        x={5.39844}
        y={7}
        width={11}
        height={8.8}
        rx={1.07135}
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M16.402 9.2h1.128c.592 0 1.072.479 1.072 1.07v6.658c0 .592-.48 1.071-1.072 1.071H8.673c-.592 0-1.071-.48-1.071-1.071v-1.129"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
