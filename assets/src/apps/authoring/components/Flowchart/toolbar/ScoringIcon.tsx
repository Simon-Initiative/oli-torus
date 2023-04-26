import * as React from 'react';

export const ScoringIcon: React.FC<{ stroke?: string }> = ({ stroke = '#222439', ...props }) => {
  return (
    <svg
      width={24}
      height={24}
      viewBox="0 0 24 24"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      {...props}
    >
      <rect width={24} height={24} rx={3} fill="#F3F5F8" />
      <path
        d="M11.822 5.353a.2.2 0 01.357 0l1.937 3.833a.2.2 0 00.15.107l4.325.618a.2.2 0 01.11.343l-3.123 2.97a.2.2 0 00-.06.18l.738 4.2a.2.2 0 01-.288.212l-3.877-1.99a.2.2 0 00-.182 0l-3.877 1.99a.2.2 0 01-.288-.212l.737-4.2a.2.2 0 00-.059-.18L5.3 10.254a.2.2 0 01.11-.343l4.325-.618a.2.2 0 00.15-.107l1.938-3.833z"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
