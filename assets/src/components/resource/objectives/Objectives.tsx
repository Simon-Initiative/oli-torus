import { Card } from 'react-bootstrap';
import React, { PropsWithChildren } from 'react';

// eslint-disable-next-line @typescript-eslint/ban-types
type Props = {};
export const Objectives = (props: PropsWithChildren<Props>) => {
  return (
    <Card>
      <Card.Body>
        <Card.Title>Learning Objectives</Card.Title>
        <div className="d-flex flex-row align-items-baseline">
          <div className="flex-grow-1">{props.children}</div>
        </div>
      </Card.Body>
    </Card>
  );
};
