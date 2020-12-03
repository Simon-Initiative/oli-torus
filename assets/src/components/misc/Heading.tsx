import React from 'react';

export type HeadingProps = {
  title: string;
  subtitle?: string;
  id: string;
};
export const Heading = ({ title, subtitle, id }: HeadingProps) => {
  return (
    <div className="mb-2">
      <h3 id={id}>
        {title}
      </h3>
      {subtitle && <p className="text-secondary">
        {subtitle}
      </p>}
    </div>
  );
};
