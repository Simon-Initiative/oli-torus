import React from 'react';

export const Description = ({ children }: React.PropsWithChildren<{}>) => {
  return (
    <div className="mb-1">
      {children}
    </div>
  );
};
