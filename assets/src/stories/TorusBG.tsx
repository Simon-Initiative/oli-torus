import React from 'react';

export const TorusBG: React.FC<{
  className?: string;
  dark?: boolean;
  style?: Record<string, string>;
}> = ({ children, className, dark, style }) => (
  <div className="w-full min-w-[800px]">
    <div
      className={`p-6 relative bg-delivery-body  text-delivery-body-color  ${className}`}
      style={style}
    >
      {children}
    </div>
    {dark && (
      <div className="dark">
        <div
          style={style}
          className={`p-6 relative  dark:bg-delivery-body-dark  dark:text-delivery-body-color-dark ${className}`}
        >
          {children}
        </div>
      </div>
    )}
  </div>
);

TorusBG.defaultProps = { dark: true };
