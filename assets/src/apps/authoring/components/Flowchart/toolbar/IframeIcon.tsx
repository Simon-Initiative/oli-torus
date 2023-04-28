import * as React from 'react';

export const IframeIcon: React.FC<{ stroke?: string; fill?: string }> = ({
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
      <path
        d="M18 14.332V9a1.333 1.333 0 00-.666-1.154L12.667 5.18a1.333 1.333 0 00-1.333 0L6.667 7.845A1.333 1.333 0 006 9v5.333a1.333 1.333 0 00.667 1.154l4.667 2.666a1.333 1.333 0 001.333 0l4.667-2.666A1.334 1.334 0 0018 14.332z"
        stroke={stroke}
        strokeWidth={0.857143}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M6.496 8.469l5.454 2.974 5.453-2.974M11.947 17.89v-6.445"
        stroke={stroke}
        strokeWidth={0.857143}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
