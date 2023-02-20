import React from 'react';

export const TorusBG: React.FC<{ className?: string }> = ({ children, className }) => (
  <div>
    <div className={`p-6 relative bg-delivery-body  text-delivery-body-color  ${className}`}>
      {children}
    </div>
    <div className="dark">
      <div
        className={`p-6 relative  dark:bg-delivery-body-dark  dark:text-delivery-body-color-dark ${className}`}
      >
        {children}
      </div>
    </div>
  </div>
);
