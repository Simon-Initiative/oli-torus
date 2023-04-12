import * as React from 'react';

export const D20: React.FC<any> = (props) => {
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
        d="M1 53.5L31 1l30 52.5H1z"
        className="icon-stroke"
        strokeWidth={2}
        strokeMiterlimit={10}
        strokeLinejoin="round"
      />
      <path
        d="M45.979 27.25L31 53.5 16 27.25h29.979z"
        className="icon-stroke"
        strokeWidth={2}
        strokeMiterlimit={10}
        strokeLinejoin="round"
      />
      <path
        d="M1 18.479l30 52.5 30-52.5H1z"
        className="icon-stroke"
        strokeWidth={2}
        strokeMiterlimit={10}
        strokeLinejoin="round"
        strokeDasharray="3 3"
      />
      <path
        d="M45.978 27.25L61 18.48M16 27.25L1 18.48M31 53.5v17.478"
        className="icon-stroke"
        strokeWidth={2}
        strokeMiterlimit={10}
        strokeLinejoin="round"
      />
    </svg>
  );
};
