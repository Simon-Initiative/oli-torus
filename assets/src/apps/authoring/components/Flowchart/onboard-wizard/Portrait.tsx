import * as React from 'react';

export const Portrait: React.FC<any> = (props) => {
  return (
    <svg
      width={82}
      height={122}
      viewBox="0 0 82 122"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <rect
        x={81}
        y={1}
        width={120}
        height={80}
        rx={4}
        transform="rotate(90 81 1)"
        className="disabled-icon-stroke"
        strokeWidth={2}
        strokeMiterlimit={10}
        strokeLinejoin="round"
        strokeDasharray="3 3"
      />
    </svg>
  );
};
