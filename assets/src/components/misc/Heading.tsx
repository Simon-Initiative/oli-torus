import React from 'react';

export type HeadingProps = {
  title: string;
  subtitle: string;
  id: string;
};
export const Heading = ({ title, subtitle, id }: HeadingProps) => {
  return (
    <React.Fragment>
      <h6 id={id}>
        {title}
      </h6>
      <small style={{ display: 'inline-block', marginBottom: '10px' }}>
        {subtitle}
      </small>
    </React.Fragment>
  );
};
