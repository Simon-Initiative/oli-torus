import React from 'react';

export const TorusBG: React.FC<{ className?: string }> = ({ children, className }) => (
  <div
    className={`p-6 relative bg-delivery-body dark:bg-delivery-body-dark text-delivery-body-color dark:text-delivery-body-color-dark ${className}`}
  >
    {children}
  </div>
);
