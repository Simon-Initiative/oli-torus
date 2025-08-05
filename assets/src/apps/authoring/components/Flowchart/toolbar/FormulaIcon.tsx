import * as React from 'react';

export const FormulaIcon: React.FC<{ stroke?: string; fill?: string }> = ({
  stroke = '#222439',
  fill = '#F3F5F8',
  ...props
}) => (
  <svg
    {...props}
    width="28"
    height="24"
    viewBox="0 0 28 24"
    xmlns="http://www.w3.org/2000/svg"
    role="img"
    aria-label="Formula icon"
  >
    {/* Full background */}
    <rect width="28" height="24" rx="4" fill={fill} />

    {/* Border around the text with extra padding */}
    <rect x="5.5" y="4" width="17" height="16" rx="3" stroke={stroke} fill="none" />

    {/* Centered text with better alignment */}
    <text
      x="14"
      y="12.5"
      textAnchor="middle"
      dominantBaseline="middle"
      fontFamily="serif"
      fontWeight="bold"
      fontSize="14"
      fill={stroke}
    >
      ƒx
    </text>
  </svg>
);
