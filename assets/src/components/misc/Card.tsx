import React, { isValidElement } from 'react';

interface Props {
  title?: JSX.Element | string;
  content?: JSX.Element | string;
}
const CardComponent: React.FC<Props> = ({ children }) => {
  return (
    <div className="card">
      <div className="card-body">
        <div className="card-title d-flex align-items-center">
          {React.Children.toArray(children).find(
            (child) => isValidElement(child) && child.type === Title,
          )}
        </div>
        {React.Children.toArray(children).find(
          (child) => isValidElement(child) && child.type === Content,
        )}
      </div>
    </div>
  );
};
const Title: React.FC = ({ children }) => <>{children}</>;
const Content: React.FC = ({ children }) => <>{children}</>;

export const Card = {
  Card: CardComponent,
  Title,
  Content,
};
