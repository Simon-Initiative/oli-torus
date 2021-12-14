import React from 'react';
export const Heading = ({ title, subtitle, id }) => {
    return (<div className="mb-2">
      <h3 id={id}>{title}</h3>
      {subtitle && <p className="text-secondary">{subtitle}</p>}
    </div>);
};
//# sourceMappingURL=Heading.jsx.map