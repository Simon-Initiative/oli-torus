import React, { isValidElement } from 'react';
const CardComponent = ({ children, className = '' }) => {
    return (<div className={`${className} card`}>
      <div className="card-body">
        <div className="card-title d-flex align-items-center">
          {React.Children.toArray(children).find((child) => isValidElement(child) && child.type === Title)}
        </div>
        {React.Children.toArray(children).find((child) => isValidElement(child) && child.type === Content)}
      </div>
    </div>);
};
const Title = ({ children }) => <>{children}</>;
const Content = ({ children }) => <>{children}</>;
export const Card = {
    Card: CardComponent,
    Title,
    Content,
};
//# sourceMappingURL=Card.jsx.map