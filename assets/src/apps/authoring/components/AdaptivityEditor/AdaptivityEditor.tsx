import React from 'react';
import { Accordion, Card } from 'react-bootstrap';
import ContextAwareToggle from '../Accordion/ContextAwareToggle';

const AdaptivityEditor: React.FC<any> = (props) => {
  return (
    <Accordion defaultActiveKey="0">
      <Card>
        <Card.Header>
          <ContextAwareToggle eventKey="0" />
          Adaptivity
        </Card.Header>
        <Accordion.Collapse eventKey="0">
          <Card.Body>adaptivity content</Card.Body>
        </Accordion.Collapse>
      </Card>
    </Accordion>
  );
};

export default AdaptivityEditor;
