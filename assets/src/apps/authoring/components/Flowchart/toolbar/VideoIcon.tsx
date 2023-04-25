import * as React from 'react';

export const VideoIcon: React.FC<{ stroke: string }> = ({ stroke = '#222439', ...props }) => {
  return (
    <svg
      width={24}
      height={24}
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <rect width={24} height={24} rx={3} fill="#F3F5F8" />
      <path
        d="M19.5 12a7.5 7.5 0 11-15 0 7.5 7.5 0 0115 0z"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path
        d="M10.89 14.307h-.001c-.389.188-.776-.103-.776-.418v-3.774c0-.33.406-.62.796-.41v.001l3.68 2.008c.345.192.336.651-.028.828 0 0 0 0 0 0l-3.671 1.765z"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
