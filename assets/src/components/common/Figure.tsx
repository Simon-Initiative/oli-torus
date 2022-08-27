import React, { ReactNode } from 'react';

export const Figure: React.FC<{
  title: string | ReactNode;
  children: ReactNode;
}> = ({ title, children }) => (
  <div className="figure">
    <figure>
      <figcaption>{title}</figcaption>
      <div className="figure-content">{children}</div>
    </figure>
  </div>
);
