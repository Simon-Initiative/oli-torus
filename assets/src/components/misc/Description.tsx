import React from 'react';

export const Description = ({ children }: React.PropsWithChildren<{}>) => {
  return (
    <span style={{ fontSize: '11px', display: 'flex', alignItems: 'center' }}>
      {children}
    </span>
  );
};
