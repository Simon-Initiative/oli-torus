import * as React from 'react';

export const RightArrow: React.FC<{ stroke?: string }> = ({ stroke = '#2C6ABF', ...props }) => {
  return (
    <svg
      width={24}
      height={24}
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className="inline"
      {...props}
    >
      <path
        d="M5 12h14M12 5l7 7-7 7"
        stroke={stroke}
        strokeWidth={1.5}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
