/* eslint-disable react/no-unknown-property */

import React from 'react';

export const TextIcon: React.FC<any> = () => {
  return (
    <svg
      width="18px"
      height="24px"
      viewBox="0 0 18 24"
      version="1.1"
      xmlns="http://www.w3.org/2000/svg"
    >
      <title>icon-text</title>
      <g
        stroke="none"
        stroke-width="1"
        fill="none"
        fill-rule="evenodd"
      >
        <g
          id="Rule-Editor-Open-Nested"
          transform="translate(-511.000000, -21.000000)"
          fill={
            window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
              ? '#ffffff'
              : '#000000'
          }
          fill-rule="nonzero"
        >
          <polygon
            id="icon-text"
            points="511 21 511 25.5000032 514.000019 25.5000032 514.000019 24.0000192 518.500022 24.0000192 518.500022 42.0000321 515.500003 42.0000321 515.500003 45.0000513 524.50001 45.0000513 524.50001 42.0000321 521.49999 42.0000321 521.49999 24.0000192 525.999994 24.0000192 525.999994 25.5000032 529.000013 25.5000032 529.000013 21"
          ></polygon>
        </g>
      </g>
    </svg>
  );
};
