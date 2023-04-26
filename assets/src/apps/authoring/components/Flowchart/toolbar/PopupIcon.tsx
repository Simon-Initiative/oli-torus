import * as React from 'react';

export const PopupIcon: React.FC<{ stroke?: string; fill?: string }> = ({
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
        d="M18 11.5v4.429C18 16.52 17.52 17 16.929 17H7.07C6.48 17 6 16.52 6 15.929V8.07C6 7.48 6.48 7 7.071 7H13.5M19 6l-3 3M19 9l-3-3"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
