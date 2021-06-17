/* eslint-disable react/no-unknown-property */

import React from 'react';

export const VideoIcon: React.FC<any> = () => {
  return (
    <svg
      width="36px"
      height="24px"
      viewBox="0 0 36 24"
      version="1.1"
      xmlns="http://www.w3.org/2000/svg"
    >
      <title>icon-video</title>
      <g
        stroke="none"
        stroke-width="1"
        fill="none"
        fill-rule="evenodd"
      >
        <g
          id="Rule-Editor-Open-Nested"
          transform="translate(-610.000000, -21.000000)"
          fill={
            window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches
              ? '#ffffff'
              : '#000000'
          }
          fill-rule="nonzero"
        >
          <path
            d="M631.0125,21 L612.9875,21 C611.3375,21 610,22.3375 610,23.9875 L610,42.0125 C610,43.6625 611.3375,45 612.9875,45 L631.0125,45 C632.6625,45 634,43.6625 634,42.0125 L634,23.9875 C634,22.3375 632.6625,21 631.0125,21 Z M642.85,23.35625 L636,28.08125 L636,37.91875 L642.85,42.6375 C644.175,43.55 646,42.61875 646,41.025 L646,24.96875 C646,23.38125 644.18125,22.44375 642.85,23.35625 Z"
            id="icon-video"
          ></path>
        </g>
      </g>
    </svg>
  );
};
