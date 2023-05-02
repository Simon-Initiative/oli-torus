import * as React from 'react';

export const ScreenDeleteIcon: React.FC<{ fill?: string; stroke?: string }> = ({
  fill = '#F3F5F8',
  stroke = '#222439',
}) => {
  return (
    <svg width={24} height={24} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width={24} height={24} rx={3} fill={fill} />
      <path
        d="M6.5 8.401h10.998M16.277 8.4v8.4c0 .318-.129.623-.358.848-.23.226-.54.352-.864.352h-6.11c-.324 0-.635-.126-.864-.352a1.189 1.189 0 01-.358-.848V8.4m1.833 0V7.2c0-.318.128-.623.358-.849.229-.225.54-.351.864-.351h2.444c.324 0 .635.126.864.351.23.226.358.53.358.849v1.2M10.82 14.701v-3.086M13.176 14.701v-3.086"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
