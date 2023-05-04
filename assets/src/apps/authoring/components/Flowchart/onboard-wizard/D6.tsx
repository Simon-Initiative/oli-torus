import * as React from 'react';

export const D6: React.FC<any> = (props) => {
  return (
    <svg
      width={62}
      height={72}
      viewBox="0 0 62 72"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <path
        d="M61 53.5v-35L31 1 1 18.5v35L31 71l30-17.5z"
        className="icon-stroke"
        strokeWidth={2}
        strokeMiterlimit={10}
        strokeLinejoin="round"
      />
      <path
        d="M61 18.5L31 36 1 18.5M31 36v35"
        className="icon-stroke"
        strokeWidth={2}
        strokeMiterlimit={10}
        strokeLinejoin="round"
      />
      <path
        d="M31 36V1M31 36L1 53.5M31 36l30 17.5"
        className="icon-stroke"
        strokeWidth={2}
        strokeMiterlimit={10}
        strokeDasharray="3 3"
      />
    </svg>
  );
};
