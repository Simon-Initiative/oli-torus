import * as React from 'react';

export const FlashcardIcon: React.FC<{ stroke?: string; fill?: string }> = ({
  stroke = '#222439',
  fill = '#F3F5F8',
  ...props
}) => (
  <svg
    width={24}
    height={24}
    viewBox="0 0 24 24"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
    {...props}
  >
    <rect width={24} height={24} rx={3} fill={fill} />
    <g fill={stroke} fillRule="evenodd">
      <rect x={8} y={2} width={12} height={16} rx={1.5} opacity={0.35} />
      <rect x={6} y={4} width={12} height={16} rx={1.5} opacity={0.6} />
      <rect x={4} y={6} width={12} height={16} rx={1.5} />
      <rect x={7} y={10} width={6} height={1.25} rx={0.625} />
      <rect x={7} y={13} width={4.5} height={1.25} rx={0.625} />
      <rect x={7} y={16} width={5.5} height={1.25} rx={0.625} />
    </g>
  </svg>
);
