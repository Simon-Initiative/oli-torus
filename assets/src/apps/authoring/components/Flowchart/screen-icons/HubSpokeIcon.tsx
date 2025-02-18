import * as React from 'react';

export const HubSpokeIcon: React.FC<{
  fill?: string;
  stroke?: string;
}> = ({ stroke = '#222439' }) => {
  return (
    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect width="24" height="24" rx="3" />
      <path
        d="M8.5 6.75v7M15.625 10.5a1.875 1.875 0 100-3.75 1.875 1.875 0 000 3.75zM8.625 17.5a1.875 1.875 0 100-3.75 1.875 1.875 0 000 3.75zM15.494 10.5a5.25 5.25 0 01-4.994 4.995"
        stroke={stroke}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
};
