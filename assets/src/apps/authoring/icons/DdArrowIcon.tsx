/* eslint-disable react/no-unknown-property */

import React from 'react';

export const DdArrowIcon: React.FC<any> = () => {
  return (
    <svg
      width="12px"
      height="8px"
      viewBox="0 0 12 8"
      version="1.1"
      xmlns="http://www.w3.org/2000/svg"
    >
      <title>icon-ddArrow</title>
      <g
        stroke="none"
        stroke-width="1"
        fill="none"
        fill-rule="evenodd"
        opacity="0.5"
      >
        <g
          id="Rule-Editor-Open-Nested"
          transform="translate(-918.000000, -29.000000)"
          fill={
            window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
              ? '#ffffff'
              : '#000000'
          }
          fill-rule="nonzero"
        >
          <path
            d="M923.028473,36.0145533 L918.247821,31.2339006 C917.917393,30.9034731 917.917393,30.3691649 918.247821,30.0422526 L919.042253,29.2478206 C919.37268,28.9173931 919.906988,28.9173931 920.233901,29.2478206 L923.62254,32.6364598 L927.011179,29.2478206 C927.341606,28.9173931 927.875915,28.9173931 928.202827,29.2478206 L928.997259,30.0422526 C929.327686,30.3726801 929.327686,30.9069883 928.997259,31.2339006 L924.216606,36.0145533 C923.893209,36.3449808 923.358901,36.3449808 923.028473,36.0145533 L923.028473,36.0145533 Z"
            id="icon-ddArrow"
          ></path>
        </g>
      </g>
    </svg>
  );
};
