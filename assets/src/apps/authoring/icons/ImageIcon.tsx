/* eslint-disable react/no-unknown-property */

import React from 'react';

export const ImageIcon: React.FC<any> = () => {
  return (
    <svg
      width="32px"
      height="24px"
      viewBox="0 0 32 24"
      version="1.1"
      xmlns="http://www.w3.org/2000/svg"
    >
      <title>icon-image</title>
      <g
        stroke="none"
        stroke-width="1"
        fill={
          window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
            ? '#ffffff'
            : '#000000'
        }
        fill-rule="evenodd"
      >
        <g
          id="Rule-Editor-Open-Nested"
          transform="translate(-554.000000, -21.000000)"
          fill={
            window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
              ? '#ffffff'
              : '#000000'
          }
          fill-rule="nonzero"
        >
          <path
            d="M583,45 L557,45 C555.343125,45 554,43.656875 554,42 L554,24 C554,22.343125 555.343125,21 557,21 L583,21 C584.656875,21 586,22.343125 586,24 L586,42 C586,43.656875 584.656875,45 583,45 Z M561,24.5 C559.067,24.5 557.5,26.067 557.5,28 C557.5,29.933 559.067,31.5 561,31.5 C562.933,31.5 564.5,29.933 564.5,28 C564.5,26.067 562.933,24.5 561,24.5 Z M558,41 L582,41 L582,34 L576.530313,28.5303125 C576.237438,28.2374375 575.762563,28.2374375 575.469625,28.5303125 L567,37 L563.530313,33.5303125 C563.237438,33.2374375 562.762563,33.2374375 562.469625,33.5303125 L558,38 L558,41 Z"
            id="icon-image"
          ></path>
        </g>
      </g>
    </svg>
  );
};
