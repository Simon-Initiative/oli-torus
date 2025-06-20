import React from 'react';

interface AIIconProps {
  className?: string;
  size?: 'sm' | 'md' | 'lg';
}

export const AIIcon: React.FC<AIIconProps> = ({ className = '', size = 'md' }) => {
  const sizeClasses = {
    sm: 'w-4 h-4',
    md: 'w-6 h-6',
    lg: 'w-8 h-8',
  };

  return (
    <svg
      width="24"
      height="26"
      viewBox="0 0 24 26"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={`${sizeClasses[size]} ${className}`}
    >
      <path
        d="M15.2715 4.90606L17.4534 9.45469L22.002 11.6366L17.4534 13.8184L15.2715 18.367L13.0897 13.8184L8.54106 11.6366L13.0897 9.45469L15.2715 4.90606Z"
        className="fill-[#0165DA] dark:fill-[#4CA6FF]"
      />
      <path
        d="M8.72741 15.4665L10.18197 18.9089L13.6244 20.3634L10.18197 21.8179L8.72741 25.2603L7.27285 21.8179L3.83041 20.3634L7.27285 18.9089L8.72741 15.4665Z"
        className="fill-[#0165DA] dark:fill-[#4CA6FF]"
      />
      <path
        d="M5.81827 1.45459L7.27283 4.36368L10.1819 5.81823L7.27283 7.27278L5.81827 10.1819L4.36371 7.27278L1.45462 5.81823L4.36371 4.36368L5.81827 1.45459Z"
        className="fill-[#0165DA] dark:fill-[#4CA6FF]"
      />
    </svg>
  );
};
